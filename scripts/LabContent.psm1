#requires -Version 5.1
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if ($PSVersionTable.PSEdition -eq 'Desktop') {
    Add-Type -AssemblyName System.IO.Compression.FileSystem
}

$script:Packages = Get-Content -LiteralPath (Join-Path $PSScriptRoot '../infra/workload-manifest.json') -Raw |
    ConvertFrom-Json

function Assert-ArchiveHash {
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][string]$ExpectedHash
    )

    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        throw "Archive not found: $Path"
    }
    if ([IO.Path]::GetExtension($Path) -ine '.zip') {
        throw "Expected a ZIP archive: $Path"
    }
    $actual = (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash
    if ($actual -ine $ExpectedHash) {
        throw "Archive SHA-256 mismatch: $Path. Expected $ExpectedHash; found $actual. Obtain the LAB720 package recorded in infra/workload-manifest.json; do not bypass the checksum."
    }
}

function Get-PayloadRoot {
    param([Parameter(Mandatory)][string]$ExtractionDirectory)

    foreach ($candidate in @((Join-Path $ExtractionDirectory 'caldova'), $ExtractionDirectory)) {
        $missing = @(
            foreach ($module in @('module-01-assess', 'module-02-plan', 'module-03-execute')) {
                foreach ($state in @('start', 'finish')) {
                    $gitDirectory = Join-Path $candidate "modules/$module/$state/.git"
                    if (-not (Test-Path -LiteralPath $gitDirectory -PathType Container)) {
                        $gitDirectory
                    }
                }
            }
        )
        if ($missing.Count -eq 0) {
            return $candidate
        }
    }
    throw 'The rehearsal archive must contain all six LAB720 start/finish repositories, including their .git directories. The separate final snapshot is not a replacement.'
}

function Assert-LabArchives {
    param([string]$LabArchive, [string]$FinalArchive)

    if ($LabArchive) { Assert-ArchiveHash -Path $LabArchive -ExpectedHash $script:Packages.rehearsal.sha256 }
    if ($FinalArchive) { Assert-ArchiveHash -Path $FinalArchive -ExpectedHash $script:Packages.final.sha256 }
}

function Get-RehearsalDownloadUri {
    $source = $script:Packages.rehearsal.url
    if ([string]::IsNullOrWhiteSpace($source)) {
        throw 'No download is configured for the LAB720 starting archive. Pass -LabArchive with an authorized local copy of caldova-rehearsal.zip. If you only have the clone, use scripts/review-final.ps1 for the final-checkpoint review.'
    }

    $uri = $null
    if (-not [uri]::TryCreate($source, [UriKind]::Absolute, [ref]$uri) -or
        $uri.Scheme -ne 'https' -or -not $uri.Host -or $uri.UserInfo -or $uri.Query -or $uri.Fragment) {
        throw 'rehearsal.url must be a stable HTTPS download URL without credentials, a query string or a fragment.'
    }
    return $uri
}

function Get-RehearsalSource {
    if (-not [string]::IsNullOrWhiteSpace($script:Packages.rehearsal.url)) {
        return [pscustomobject]@{ Kind = 'Url'; Uri = Get-RehearsalDownloadUri }
    }

    $releaseProperty = $script:Packages.rehearsal.PSObject.Properties['githubRelease']
    if (-not $releaseProperty -or -not $releaseProperty.Value) {
        throw 'No download is configured for the LAB720 starting archive. Pass -LabArchive with an authorized local copy of caldova-rehearsal.zip. If you only have the clone, use scripts/review-final.ps1 for the final-checkpoint review.'
    }
    $release = @{}
    foreach ($name in @('repository', 'tag', 'asset')) {
        $field = $releaseProperty.Value.PSObject.Properties[$name]
        $release[$name] = if ($field) { [string]$field.Value } else { '' }
    }
    if ($release.repository -notmatch '^[A-Za-z0-9-]+/[A-Za-z0-9._-]+$' -or
        $release.tag -notmatch '^[A-Za-z0-9._-]+$' -or
        $release.asset -cne $script:Packages.rehearsal.fileName) {
        throw 'rehearsal.githubRelease must name an owner/repository, a release tag and the caldova-rehearsal.zip asset.'
    }
    return [pscustomobject]@{
        Kind       = 'GitHubRelease'
        Repository = $release.repository
        Tag        = $release.tag
        Asset      = $release.asset
    }
}

function Save-RehearsalFromGitHubRelease {
    param(
        [Parameter(Mandatory)]$Source,
        [Parameter(Mandatory)][string]$Directory
    )

    $help = "Ask your lab organizer to give your GitHub account read access to https://github.com/$($Source.Repository), or pass -LabArchive with a local copy of $($Source.Asset). If you only have the clone, use scripts/review-final.ps1 for the final-checkpoint review."
    if (-not (Get-Command gh -ErrorAction SilentlyContinue)) {
        throw "GitHub CLI (gh) is required to download the LAB720 starting archive. $help"
    }

    & gh auth status --hostname github.com *> $null
    if ($LASTEXITCODE -ne 0) {
        # gh auth login --web waits for a browser, so only start it when someone can respond.
        if ([Environment]::UserInteractive -and -not [Console]::IsInputRedirected -and -not $env:CI) {
            Write-Host 'Sign in to GitHub so setup can download the LAB720 starting archive...'
            & gh auth login --hostname github.com --web --git-protocol https
        }
        if ($LASTEXITCODE -ne 0) {
            throw "Sign in to GitHub with 'gh auth login', then rerun setup. $help"
        }
    }

    Write-Host "Downloading $($Source.Asset) from $($Source.Repository) release $($Source.Tag)..."
    & gh release download $Source.Tag --repo $Source.Repository --pattern $Source.Asset --dir $Directory
    $archive = Join-Path $Directory $Source.Asset
    if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath $archive -PathType Leaf)) {
        throw "Could not download the LAB720 starting archive with your GitHub account. $help"
    }
    return $archive
}

function Assert-FinalSnapshot {
    param([Parameter(Mandatory)][string]$Root)

    $manifestPath = Join-Path $Root 'manifest.json'
    if (-not (Test-Path -LiteralPath $manifestPath -PathType Leaf)) {
        throw "Frozen final manifest is missing: $manifestPath"
    }
    if ((Get-FileHash -LiteralPath $manifestPath -Algorithm SHA256).Hash -ine $script:Packages.final.manifestSha256) {
        throw "The frozen final manifest has changed: $manifestPath"
    }
    $manifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
    $files = @($manifest.files.PSObject.Properties)
    if ($files.Count -ne $script:Packages.final.fileCount) {
        throw "The frozen final manifest must list $($script:Packages.final.fileCount) files."
    }
    foreach ($entry in $files) {
        if ([IO.Path]::IsPathRooted($entry.Name) -or $entry.Name -match '(^|[\\/])\.\.([\\/]|$)') {
            throw "Invalid path in frozen final manifest: $($entry.Name)"
        }
        $file = Join-Path $Root $entry.Name
        if (-not (Test-Path -LiteralPath $file -PathType Leaf) -or
            (Get-FileHash -LiteralPath $file -Algorithm SHA256).Hash -ine $entry.Value) {
            throw "Frozen final file is missing or changed: $file. Do not repair it with a start/finish file."
        }
    }
}

function Expand-LabContent {
    param(
        [Parameter(Mandatory)][string]$LabArchive,
        [Parameter(Mandatory)][string]$StagingDirectory,
        [string]$FinalArchive
    )

    Assert-LabArchives -LabArchive $LabArchive
    $rehearsalDirectory = Join-Path $StagingDirectory 'rehearsal'
    [IO.Compression.ZipFile]::ExtractToDirectory($LabArchive, $rehearsalDirectory)
    $payloadRoot = Get-PayloadRoot -ExtractionDirectory $rehearsalDirectory
    $finalDirectory = Join-Path $payloadRoot 'modules/module-03-execute/final'
    if (Test-Path -LiteralPath $finalDirectory) {
        throw 'The rehearsal package unexpectedly contains a final directory. Keep the two LAB720 packages separate.'
    }
    Expand-FinalSnapshot -Destination $finalDirectory -StagingDirectory $StagingDirectory -FinalArchive $FinalArchive
    return $payloadRoot
}

function Expand-FinalSnapshot {
    param(
        [Parameter(Mandatory)][string]$Destination,
        [Parameter(Mandatory)][string]$StagingDirectory,
        [string]$FinalArchive
    )

    if (Test-Path -LiteralPath $Destination) {
        throw "Final checkpoint directory already exists: $Destination. Refusing to overwrite it."
    }
    if (-not $FinalArchive) {
        $FinalArchive = Join-Path $StagingDirectory $script:Packages.final.fileName
        Write-Host 'Downloading the separate frozen final checkpoint used by LAB720...'
        Invoke-WebRequest -UseBasicParsing -Uri $script:Packages.final.url -OutFile $FinalArchive
    }
    Assert-ArchiveHash -Path $FinalArchive -ExpectedHash $script:Packages.final.sha256
    $FinalArchive = (Get-Item -LiteralPath $FinalArchive).FullName
    [IO.Compression.ZipFile]::ExtractToDirectory($FinalArchive, $Destination)
    Assert-FinalSnapshot -Root (Join-Path $Destination 'dotnet')
}

function Invoke-LabGit {
    param(
        [Parameter(Mandatory)][string]$Repository,
        [Parameter(Mandatory)][string[]]$Arguments
    )

    # Never execute hooks carried in a historical teaching archive.
    $output = @(& git -c "core.hooksPath=$PSScriptRoot/disabled-hooks" -C $Repository @Arguments)
    if ($LASTEXITCODE -ne 0) {
        throw "git $($Arguments -join ' ') failed in $Repository (exit code $LASTEXITCODE)."
    }
    return $output
}

function Initialize-LabContent {
    param([Parameter(Mandatory)][string]$Root)

    foreach ($module in @('module-01-assess', 'module-02-plan', 'module-03-execute')) {
        foreach ($state in @('start', 'finish')) {
            $repository = Join-Path $Root "modules/$module/$state"
            Invoke-LabGit -Repository $repository -Arguments @('show-ref', '--verify', '--quiet', 'refs/heads/main') | Out-Null
            $changes = @(Invoke-LabGit -Repository $repository -Arguments @('status', '--porcelain'))
            if ($changes.Count -gt 0) {
                throw "The extracted repository is not clean: $repository. Refusing to switch branches."
            }
        }
    }
    $branches = @{
        'modules/module-02-plan/start' = 'main'
        'modules/module-03-execute/start' = 'modernization/dotnet'
        'modules/module-03-execute/finish' = 'modernization/dotnet'
    }
    foreach ($entry in $branches.GetEnumerator()) {
        Invoke-LabGit -Repository (Join-Path $Root $entry.Key) `
            -Arguments @('switch', '--quiet', '--no-guess', $entry.Value) | Out-Null
    }
    Assert-LabContent -Root $Root -CheckPreparedStart
}

function Assert-LabContent {
    param([Parameter(Mandatory)][string]$Root, [switch]$CheckPreparedStart)

    Get-PayloadRoot -ExtractionDirectory $Root | Out-Null
    $executionPlan = 'modules/module-03-execute/start/apps/CaldovaAuthGateway/.github/modernize/caldova-dotnet-modernization'
    $requiredFiles = @(
        'modules/module-02-plan/start/goals/dotnet.txt',
        'modules/module-02-plan/start/skills/pii-masking/SKILL.md',
        'modules/module-02-plan/start/rulebook/charter.md',
        'modules/module-02-plan/start/rulebook/policies.md',
        'modules/module-02-plan/start/rulebook/targets.md',
        'modules/module-02-plan/start/apps/CaldovaAuthGateway/CaldovaAuthGateway.csproj',
        'modules/module-03-execute/start/apps/CaldovaAuthGateway/CaldovaAuthGateway.csproj',
        "$executionPlan/plan.md",
        "$executionPlan/rulebook-compliance.md",
        "$executionPlan/.metadata/tasks.json",
        'modules/module-03-execute/finish/apps/CaldovaAuthGateway/CaldovaAuthGateway.csproj',
        'modules/module-03-execute/finish/apps/CaldovaAuthGateway/Tests/CaldovaAuthGateway.Tests.csproj',
        'modules/module-03-execute/finish/apps/CaldovaLoanPortal/Dockerfile',
        'modules/module-03-execute/finish/apps/CaldovaLoanPortal/CaldovaLoanPortal.csproj'
    )
    foreach ($relativePath in $requiredFiles) {
        if (-not (Test-Path -LiteralPath (Join-Path $Root $relativePath) -PathType Leaf)) {
            throw "A guide-required file is missing: $relativePath. This is not a ready LAB720 workspace."
        }
    }
    if ($CheckPreparedStart) {
        $planRoot = Join-Path $Root $executionPlan
        foreach ($name in @('plan.md', 'rulebook-compliance.md')) {
            if ([string]::IsNullOrWhiteSpace([IO.File]::ReadAllText((Join-Path $planRoot $name)))) {
                throw "The prepared $name is empty. The execution-start checkpoint is not ready."
            }
        }
        $tasksPath = Join-Path $planRoot '.metadata/tasks.json'
        $json = [IO.File]::ReadAllText($tasksPath)
        try { $state = ConvertFrom-Json -InputObject $json -ErrorAction Stop }
        catch { throw "Invalid JSON in the prepared task state: $tasksPath" }
        if ($null -eq $state -or -not $state.PSObject.Properties['tasks'] -or $state.tasks -isnot [array]) {
            throw "Expected a tasks array in the prepared task state: $tasksPath"
        }
        foreach ($id in @('001-upgrade-dotnet-framework-to-net10', '002-transform-webforms-ashx-to-aspnetcore-mvc')) {
            $entries = @($state.tasks | Where-Object { $_ -and $_.PSObject.Properties['id'] -and $_.id -is [string] -and $_.id -ceq $id })
            if ($entries.Count -ne 1 -or -not $entries[0].PSObject.Properties['status'] -or
                $entries[0].status -isnot [string] -or $entries[0].status -cne 'success') {
                throw "Expected exactly one prepared task '$id' with status 'success' in $tasksPath. Do not start execution."
            }
        }
    }
    $assessmentRoot = Join-Path $Root 'modules/module-01-assess/start/.github/modernize/assessment-prebuilt'
    if (-not (Test-Path -LiteralPath $assessmentRoot -PathType Container)) {
        throw "The prepared LAB720 assessment directory is missing: $assessmentRoot"
    }
    $reports = @(Get-ChildItem -LiteralPath $assessmentRoot -Directory -Filter 'reports-*')
    # The prepared report predates the Caldova rename, so it lists the gateway as ZavaAuthGateway.
    $completeReports = @($reports | Where-Object {
        (Test-Path -LiteralPath (Join-Path $_.FullName 'index.html') -PathType Leaf) -and
        (Test-Path -LiteralPath (Join-Path $_.FullName 'repos/ZavaAuthGateway/facts/data-architecture.md') -PathType Leaf) -and
        (Test-Path -LiteralPath (Join-Path $_.FullName 'repos/ZavaAuthGateway/facts/configuration-inventory.md') -PathType Leaf)
    })
    if ($completeReports.Count -eq 0) {
        throw 'The prepared LAB720 assessment is missing its report or gateway database/configuration facts.'
    }
    Assert-FinalSnapshot -Root (Join-Path $Root 'modules/module-03-execute/final/dotnet')
}

Export-ModuleMember -Function Expand-LabContent, Initialize-LabContent, Assert-LabContent, Expand-FinalSnapshot, Assert-LabArchives, Get-RehearsalDownloadUri, Get-RehearsalSource, Save-RehearsalFromGitHubRelease
