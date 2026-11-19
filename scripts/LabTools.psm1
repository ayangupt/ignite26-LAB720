#requires -Version 5.1
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Test-LabGitHubCli {
    if (-not (Get-Command gh -ErrorAction SilentlyContinue)) { return $false }
    $output = @(& gh --version)
    if ($LASTEXITCODE -ne 0 -or $output.Count -eq 0 -or $output[0] -notmatch '^gh version (\d+\.\d+\.\d+)\b') {
        throw 'Unable to determine the GitHub CLI version. Repair gh or check which executable is on PATH.'
    }
    $version = [version]$Matches[1]
    Write-Host "GitHub CLI version: $version"
    return $version -ge [version]'2.45.0'
}

Export-ModuleMember -Function Test-LabGitHubCli
