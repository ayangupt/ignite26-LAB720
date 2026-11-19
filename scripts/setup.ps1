#requires -Version 7.0
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$LabArchive,

    [string]$FinalArchive,

    [string]$LabRoot = 'C:\lab\caldova',

    [switch]$SkipToolInstallation
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if (-not $IsWindows) {
    throw 'The automated setup currently supports Windows 11 only. Follow the official tool installation instructions to set up a different platform manually.'
}

Import-Module (Join-Path $PSScriptRoot 'LabContent.psm1')

function Test-Command {
    param([Parameter(Mandatory = $true)][string]$Name)
    return $null -ne (Get-Command $Name -ErrorAction SilentlyContinue)
}

function Sync-SessionPath {
    $entries = @(
        [Environment]::GetEnvironmentVariable('Path', 'Machine'),
        [Environment]::GetEnvironmentVariable('Path', 'User'),
        $env:Path
    ) -join [IO.Path]::PathSeparator -split [IO.Path]::PathSeparator |
        Where-Object { $_ } |
        Select-Object -Unique
    $env:Path = $entries -join [IO.Path]::PathSeparator
}

function Invoke-WinGetInstall {
    param([Parameter(Mandatory = $true)][string]$Id)

    # winget reports these when the package is already present but not yet on this session's PATH.
    $alreadyInstalledCodes = @(
        -1978335135, # 0x8A150061 APPINSTALLER_CLI_ERROR_PACKAGE_ALREADY_INSTALLED
        -1978334963, # 0x8A15010D APPINSTALLER_CLI_ERROR_INSTALL_ALREADY_INSTALLED
        -1978335189  # 0x8A15002B APPINSTALLER_CLI_ERROR_UPDATE_NOT_APPLICABLE
    )

    Write-Host "Installing $Id..."
    & winget install --id $Id --exact --accept-package-agreements --accept-source-agreements
    if ($LASTEXITCODE -ne 0 -and $alreadyInstalledCodes -notcontains $LASTEXITCODE) {
        throw "winget failed to install $Id (exit code $LASTEXITCODE)."
    }
}

function Install-WinGetPackage {
    param(
        [Parameter(Mandatory = $true)][string]$Id,
        [Parameter(Mandatory = $true)][string]$Command
    )

    if (Test-Command $Command) {
        Write-Host "$Command is already installed."
        return
    }

    Invoke-WinGetInstall -Id $Id
}

function Install-ModernizeCli {
    $installerPath = Join-Path ([IO.Path]::GetTempPath()) "modernize-install-$([guid]::NewGuid()).ps1"
    try {
        Write-Host 'Downloading the official Modernize CLI installer...'
        Invoke-WebRequest `
            -Uri 'https://raw.githubusercontent.com/microsoft/modernize-cli/main/scripts/install.ps1' `
            -OutFile $installerPath
        # The installer calls exit on failure, so run it in a child process and check its exit code.
        & ([Environment]::ProcessPath) -NoProfile -ExecutionPolicy Bypass -File $installerPath
        if ($LASTEXITCODE -ne 0) {
            throw "The Modernize CLI installer failed (exit code $LASTEXITCODE)."
        }
    }
    finally {
        if (Test-Path -LiteralPath $installerPath) {
            Remove-Item -LiteralPath $installerPath -Force
        }
    }
}

$archivePath = [IO.Path]::GetFullPath($LabArchive)
if (-not (Test-Path -LiteralPath $archivePath -PathType Leaf)) {
    throw "Lab archive not found: $archivePath. Obtain an authorized Caldova modernization archive before running setup."
}
$archiveExtension = [IO.Path]::GetExtension($archivePath)
if (-not $archiveExtension.Equals('.zip', [StringComparison]::OrdinalIgnoreCase)) {
    throw 'LabArchive must be a .zip file.'
}
Sync-SessionPath
if (-not $SkipToolInstallation -and -not (Test-Command 'winget')) {
    throw 'winget is not available. Install or update App Installer from the Microsoft Store, or rerun with -SkipToolInstallation after installing prerequisites manually.'
}

$destination = [IO.Path]::GetFullPath($LabRoot)
if (Test-Path -LiteralPath $destination) {
    throw "LabRoot already exists: $destination. Setup will not overwrite a learner workspace; choose a new path or move the existing folder yourself."
}

# Stage beside the destination so the final move stays on one volume and extracted paths stay short.
$destinationParent = [IO.Path]::GetDirectoryName($destination)
[IO.Directory]::CreateDirectory($destinationParent) | Out-Null
$stagingDirectory = Join-Path $destinationParent ".lab720-staging-$([guid]::NewGuid().ToString('N').Substring(0, 8))"
try {
    [IO.Directory]::CreateDirectory($stagingDirectory) | Out-Null
    $payloadRoot = Expand-LabContent -LabArchive $archivePath -FinalArchive $FinalArchive -StagingDirectory $stagingDirectory

    $configSource = Join-Path $PSScriptRoot '..\infra\modernize-config.json'
    if (-not (Test-Path -LiteralPath $configSource -PathType Leaf)) {
        throw "Modernize configuration is missing from this repository: $configSource"
    }
    $rootReadmeSource = Join-Path $PSScriptRoot '..\infra\lab-root-README.md'
    if (-not (Test-Path -LiteralPath $rootReadmeSource -PathType Leaf)) {
        throw "The participant README is missing from this repository: $rootReadmeSource"
    }

    if (-not $SkipToolInstallation) {
        Install-WinGetPackage -Id 'Git.Git' -Command 'git'
        Install-WinGetPackage -Id 'GitHub.cli' -Command 'gh'
        Install-WinGetPackage -Id 'Microsoft.VisualStudioCode' -Command 'code'

        $hasDotNet10 = $false
        if (Test-Command 'dotnet') {
            $hasDotNet10 = @(& dotnet --list-sdks | Where-Object { $_ -match '^10\.' }).Count -gt 0
        }
        if (-not $hasDotNet10) {
            Invoke-WinGetInstall -Id 'Microsoft.DotNet.SDK.10'
        }

        Sync-SessionPath
        foreach ($command in @('git', 'gh', 'code')) {
            if (-not (Test-Command $command)) {
                throw "'$command' was installed but is not on PATH. Open a new PowerShell 7 terminal and rerun setup."
            }
        }
        if (-not (Test-Command 'dotnet') -or
            @(& dotnet --list-sdks | Where-Object { $_ -match '^10\.' }).Count -eq 0) {
            throw 'The .NET 10 SDK installation was not detected. Open a new terminal or install the SDK manually.'
        }

        Install-ModernizeCli
        Sync-SessionPath
        if (-not (Test-Command 'modernize')) {
            throw 'The Modernize CLI installation was not detected. Open a new terminal or install it manually from the official quickstart.'
        }

        foreach ($extension in @('GitHub.copilot', 'GitHub.copilot-chat')) {
            Write-Host "Installing VS Code extension $extension..."
            & code --install-extension $extension --force
            if ($LASTEXITCODE -ne 0) {
                throw "VS Code failed to install extension $extension (exit code $LASTEXITCODE)."
            }
        }
    }

    if (-not (Test-Command 'git')) {
        throw 'Git is required to select the prepared LAB720 branches. Install Git before using -SkipToolInstallation.'
    }
    Initialize-LabContent -Root $payloadRoot

    $archiveReadme = Join-Path $payloadRoot 'README.md'
    $originalReadme = Join-Path $payloadRoot 'README-ORIGINAL.md'
    if ((Test-Path -LiteralPath $archiveReadme -PathType Leaf) -and
        (Test-Path -LiteralPath $originalReadme)) {
        throw 'The archive already contains README-ORIGINAL.md; refusing to overwrite it.'
    }
    if (Test-Path -LiteralPath $archiveReadme -PathType Leaf) {
        Move-Item -LiteralPath $archiveReadme -Destination $originalReadme
    }
    Copy-Item -LiteralPath $rootReadmeSource -Destination (Join-Path $payloadRoot 'README.md')

    $launchDirectories = @(
        'modules\module-02-plan\start',
        'modules\module-03-execute\start',
        'modules\module-02-plan\start\apps\CaldovaAuthGateway',
        'modules\module-03-execute\start\apps\CaldovaAuthGateway'
    )
    foreach ($relativeDirectory in $launchDirectories) {
        $launchPath = Join-Path $payloadRoot $relativeDirectory
        $modernizeDirectory = Join-Path $launchPath '.github\modernize'
        [IO.Directory]::CreateDirectory($modernizeDirectory) | Out-Null
        Copy-Item -LiteralPath $configSource -Destination (Join-Path $modernizeDirectory 'config.json') -Force
    }

    if (Test-Path -LiteralPath $destination) {
        throw "LabRoot appeared during setup: $destination. Refusing to overwrite or nest the workspace."
    }
    $resolvedPayloadRoot = (Resolve-Path -LiteralPath $payloadRoot).Path
    [IO.Directory]::Move($resolvedPayloadRoot, $destination)

    Write-Host "Lab content installed at: $destination"
    Write-Host 'Next: open a new PowerShell 7 terminal, sign in to GitHub in gh and VS Code, then run scripts/verify.ps1.'
}
finally {
    if (Test-Path -LiteralPath $stagingDirectory) {
        Remove-Item -LiteralPath $stagingDirectory -Recurse -Force
    }
}
