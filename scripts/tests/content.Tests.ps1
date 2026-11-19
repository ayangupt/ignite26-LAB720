#requires -Version 7.0
[CmdletBinding()]
param(
    [string]$FinalArchive
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$repositoryRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
$contentModule = Import-Module (Join-Path $repositoryRoot 'scripts/LabContent.psm1') -Force -PassThru
$packages = Get-Content -LiteralPath (Join-Path $repositoryRoot 'infra/workload-manifest.json') -Raw | ConvertFrom-Json
$testRoot = Join-Path ([IO.Path]::GetTempPath()) "lab720-tests-$([guid]::NewGuid().ToString('N').Substring(0, 8))"
$script:passed = 0

function Assert-True {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) { throw $Message }
}

function Assert-Throws {
    param([scriptblock]$Action, [string]$Pattern)
    try { & $Action }
    catch {
        if ($_.Exception.Message -like $Pattern) { return }
        throw
    }
    throw "Expected an error matching: $Pattern"
}

function Test-Case {
    param([string]$Name, [scriptblock]$Action)
    & $Action
    $script:passed++
    Write-Host "PASS: $Name"
}

function Write-FixtureFile {
    param([string]$Root, [string]$Path, [string]$Content = 'Synthetic test fixture, not LAB720 teaching content.')
    $file = Join-Path $Root $Path
    [IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($file)) | Out-Null
    [IO.File]::WriteAllText($file, $Content)
}

function Invoke-FixtureGit {
    param([string]$Root, [string[]]$Arguments)
    $output = @(& git -C $Root @Arguments)
    if ($LASTEXITCODE -ne 0) { throw "Fixture git failed: $($Arguments -join ' ')" }
    return $output
}

try {
    [IO.Directory]::CreateDirectory($testRoot) | Out-Null
    Test-Case 'All production PowerShell files parse unchanged' {
        foreach ($file in Get-ChildItem (Join-Path $repositoryRoot 'scripts') -File |
            Where-Object Extension -In '.ps1', '.psm1') {
            $parseErrors = $null
            [Management.Automation.Language.Parser]::ParseFile($file.FullName, [ref]$null, [ref]$parseErrors) | Out-Null
            Assert-True ($parseErrors.Count -eq 0) "$($file.Name): $parseErrors"
        }
    }

    if (-not $FinalArchive) {
        $FinalArchive = Join-Path $testRoot $packages.final.fileName
        Invoke-WebRequest -Uri $packages.final.url -OutFile $FinalArchive
    }
    $FinalArchive = [IO.Path]::GetFullPath($FinalArchive)
    Test-Case 'The real published final package matches the LAB720 handoff digest' {
        Assert-True ((Get-FileHash -LiteralPath $FinalArchive -Algorithm SHA256).Hash -ieq $packages.final.sha256) 'Unexpected final archive checksum.'
    }

    $sourceDirectory = Join-Path $testRoot 'source'
    $fixtureRoot = Join-Path $sourceDirectory 'caldova'
    Write-FixtureFile $fixtureRoot 'README.md' 'Original fixture entry point.'
    foreach ($module in @('module-01-assess', 'module-02-plan', 'module-03-execute')) {
        foreach ($state in @('start', 'finish')) {
            $repo = Join-Path $fixtureRoot "modules/$module/$state"
            [IO.Directory]::CreateDirectory($repo) | Out-Null
            Invoke-FixtureGit $repo @('init', '--quiet', '--initial-branch=main') | Out-Null
            Invoke-FixtureGit $repo @('config', 'user.name', 'LAB720 fixture') | Out-Null
            Invoke-FixtureGit $repo @('config', 'user.email', 'fixture@example.invalid') | Out-Null
            Invoke-FixtureGit $repo @('config', 'core.autocrlf', 'false') | Out-Null
            Invoke-FixtureGit $repo @('config', 'commit.gpgSign', 'false') | Out-Null
            Invoke-FixtureGit $repo @('config', 'core.hooksPath', (Join-Path $testRoot 'disabled-hooks')) | Out-Null
            Write-FixtureFile $repo 'baseline.txt'
            if ($module -eq 'module-01-assess' -and $state -eq 'start') {
                $report = '.github/modernize/assessment-prebuilt/reports-fixture'
                Write-FixtureFile $repo "$report/index.html" '<html>Fixture report</html>'
                Write-FixtureFile $repo "$report/repos/CaldovaAuthGateway/facts/data-architecture.md"
                Write-FixtureFile $repo "$report/repos/CaldovaAuthGateway/facts/configuration-inventory.md"
            }
            if ($module -eq 'module-02-plan' -and $state -eq 'start') {
                foreach ($file in @('goals/dotnet.txt', 'skills/pii-masking/SKILL.md',
                    'rulebook/charter.md', 'rulebook/policies.md', 'rulebook/targets.md',
                    'apps/CaldovaAuthGateway/CaldovaAuthGateway.csproj')) {
                    Write-FixtureFile $repo $file
                }
            }
            Invoke-FixtureGit $repo @('add', '.') | Out-Null
            Invoke-FixtureGit $repo @('commit', '--quiet', '-m', 'Synthetic baseline') | Out-Null
            Invoke-FixtureGit $repo @('switch', '--quiet', '-c', 'modernization/dotnet') | Out-Null
            if ($module -eq 'module-03-execute') {
                if ($state -eq 'start') {
                    $plan = 'apps/CaldovaAuthGateway/.github/modernize/caldova-dotnet-modernization'
                    Write-FixtureFile $repo "$plan/plan.md"
                    Write-FixtureFile $repo "$plan/.metadata/tasks.json" '{"tasks":[]}'
                    Write-FixtureFile $repo 'apps/CaldovaAuthGateway/CaldovaAuthGateway.csproj' '<Project />'
                }
                else {
                    Write-FixtureFile $repo 'apps/CaldovaAuthGateway/CaldovaAuthGateway.csproj' '<Project />'
                    Write-FixtureFile $repo 'apps/CaldovaAuthGateway/Tests/CaldovaAuthGateway.Tests.csproj' '<Project />'
                    Write-FixtureFile $repo 'apps/CaldovaLoanPortal/Dockerfile' 'FROM mono:6.12'
                    Write-FixtureFile $repo 'apps/CaldovaLoanPortal/CaldovaLoanPortal.csproj' '<Project />'
                }
                Invoke-FixtureGit $repo @('add', '.') | Out-Null
                Invoke-FixtureGit $repo @('commit', '--quiet', '-m', 'Synthetic prepared branch') | Out-Null
            }
            Invoke-FixtureGit $repo @('switch', '--quiet', 'main') | Out-Null
        }
    }
    $archive = Join-Path $testRoot 'fixture.zip'
    [IO.Compression.ZipFile]::CreateFromDirectory($sourceDirectory, $archive)
    $staging = Join-Path $testRoot 'staging'

    $reviewScript = Join-Path $repositoryRoot 'scripts/review-final.ps1'
    $review = Join-Path $testRoot 'final review [1]'
    Test-Case 'The public review rejects a starting ZIP and cleans staging' {
        Assert-Throws { & $reviewScript -FinalArchive $archive -Destination $review } '*SHA-256 mismatch*'
        Assert-True (-not (Test-Path -LiteralPath $review)) 'Wrong ZIP left a review destination.'
        Assert-True (@(Get-ChildItem -LiteralPath $testRoot -Directory -Force -Filter '.lab720-review-*').Count -eq 0) 'Review staging leaked after failure.'
    }
    Test-Case 'The public review installs only the real final checkpoint from a local ZIP' {
        & $reviewScript -FinalArchive $FinalArchive -Destination $review
        $entries = @(Get-ChildItem -LiteralPath $review -Force)
        Assert-True ($entries.Count -eq 1 -and $entries[0].Name -ceq 'dotnet') 'The review should contain only the final dotnet folder.'
        Assert-True (Test-Path -LiteralPath (Join-Path $review 'dotnet/VALIDATION.md') -PathType Leaf) 'Final validation record missing.'
        Assert-True (@(Get-ChildItem -LiteralPath $testRoot -Directory -Force -Filter '.lab720-review-*').Count -eq 0) 'Review staging leaked after success.'
    }
    Test-Case 'A second public review preserves the existing workspace' {
        Write-FixtureFile $review 'notes.txt' 'Learner notes'
        Assert-Throws { & $reviewScript -FinalArchive $FinalArchive -Destination $review } '*destination already exists*'
        Assert-True ([IO.File]::ReadAllText((Join-Path $review 'notes.txt')) -ceq 'Learner notes') 'Existing review was overwritten.'
    }

    Test-Case 'A non-LAB720 starting archive is rejected before extraction' {
        Assert-Throws { Expand-LabContent -LabArchive $archive -FinalArchive $FinalArchive -StagingDirectory $staging } '*SHA-256 mismatch*'
        Assert-True (-not (Test-Path -LiteralPath $staging)) 'Checksum failure wrote content.'
    }

    # Replace only the rehearsal digest in this test process; production code and the real final stay unchanged.
    & $contentModule { param($Hash) $script:Packages.rehearsal.sha256 = $Hash } (Get-FileHash -LiteralPath $archive -Algorithm SHA256).Hash
    Test-Case 'Two separate archives assemble without a final folder in the rehearsal' {
        $script:payload = Expand-LabContent -LabArchive $archive -FinalArchive $FinalArchive -StagingDirectory $staging
        Assert-True (Test-Path -LiteralPath (Join-Path $script:payload 'modules/module-03-execute/final/dotnet/manifest.json')) 'Final checkpoint was not installed.'
    }
    $payload = $script:payload
    Test-Case 'The final manifest checks all 84 real files' {
        & $contentModule { param($Root) Assert-FinalSnapshot -Root $Root } (Join-Path $payload 'modules/module-03-execute/final/dotnet')
    }
    Test-Case 'The prepared branches are selected without rewriting any refs' {
        $before = @{}
        foreach ($module in @('module-01-assess', 'module-02-plan', 'module-03-execute')) {
            foreach ($state in @('start', 'finish')) {
                $repo = Join-Path $payload "modules/$module/$state"
                $before[$repo] = (Invoke-FixtureGit $repo @('show-ref', '--heads')) -join "`n"
            }
        }
        Initialize-LabContent -Root $payload
        foreach ($repo in $before.Keys) {
            Assert-True (((Invoke-FixtureGit $repo @('show-ref', '--heads')) -join "`n") -ceq $before[$repo]) "Refs changed: $repo"
        }
        foreach ($state in @('start', 'finish')) {
            $repo = Join-Path $payload "modules/module-03-execute/$state"
            Assert-True ((Invoke-FixtureGit $repo @('branch', '--show-current')) -eq 'modernization/dotnet') 'Prepared branch was not selected.'
        }
    }
    Test-Case 'A dirty workspace is not reset or switched' {
        $file = Join-Path $payload 'modules/module-03-execute/start/baseline.txt'
        $original = [IO.File]::ReadAllText($file)
        [IO.File]::WriteAllText($file, 'Learner changes')
        Assert-Throws { Initialize-LabContent -Root $payload } '*not clean*'
        Assert-True ([IO.File]::ReadAllText($file) -eq 'Learner changes') 'Learner changes were overwritten.'
        [IO.File]::WriteAllText($file, $original)
    }
    Test-Case 'Missing prepared branches fail rather than falling back to main' {
        $repo = Join-Path $payload 'modules/module-03-execute/start'
        $commit = @(Invoke-FixtureGit $repo @('rev-parse', 'modernization/dotnet'))[0]
        Invoke-FixtureGit $repo @('switch', '--quiet', 'main') | Out-Null
        Invoke-FixtureGit $repo @('branch', '-D', 'modernization/dotnet') | Out-Null
        Assert-Throws { Initialize-LabContent -Root $payload } '*git switch*failed*'
        Invoke-FixtureGit $repo @('branch', 'modernization/dotnet', $commit) | Out-Null
        Initialize-LabContent -Root $payload
    }
    Test-Case 'Missing assessment facts fail validation' {
        $file = Join-Path $payload 'modules/module-01-assess/start/.github/modernize/assessment-prebuilt/reports-fixture/repos/CaldovaAuthGateway/facts/data-architecture.md'
        Move-Item -LiteralPath $file -Destination "$file.saved"
        Assert-Throws { Assert-LabContent -Root $payload } '*assessment is missing*'
        Move-Item -LiteralPath "$file.saved" -Destination $file
    }
    Test-Case 'Missing PII skill content fails validation' {
        $file = Join-Path $payload 'modules/module-02-plan/start/skills/pii-masking/SKILL.md'
        Move-Item -LiteralPath $file -Destination "$file.saved"
        Assert-Throws { Assert-LabContent -Root $payload } '*guide-required file is missing*'
        Move-Item -LiteralPath "$file.saved" -Destination $file
    }
    Test-Case 'Changed frozen final files fail validation' {
        $file = Join-Path $payload 'modules/module-03-execute/final/dotnet/README.md'
        $original = [IO.File]::ReadAllBytes($file)
        [IO.File]::WriteAllText($file, 'Changed final')
        Assert-Throws { Assert-LabContent -Root $payload } '*Frozen final file is missing or changed*'
        [IO.File]::WriteAllBytes($file, $original)
    }
    Test-Case 'Changing the final manifest cannot bless changed content' {
        $file = Join-Path $payload 'modules/module-03-execute/final/dotnet/manifest.json'
        $original = [IO.File]::ReadAllBytes($file)
        [IO.File]::WriteAllText($file, '{"files":{}}')
        Assert-Throws { Assert-LabContent -Root $payload } '*frozen final manifest has changed*'
        [IO.File]::WriteAllBytes($file, $original)
    }
    Test-Case 'A wrong final ZIP is rejected' {
        Assert-Throws { Expand-LabContent -LabArchive $archive -FinalArchive $archive -StagingDirectory (Join-Path $testRoot 'bad-final') } '*SHA-256 mismatch*'
    }
    Test-Case 'The automatic download selects the pinned URL and installs the separate final' {
        & $contentModule {
            param($Path)
            $script:FixtureFinalArchive = $Path
            function script:Invoke-WebRequest {
                param($Uri, $OutFile, [switch]$UseBasicParsing)
                if ($Uri -cne $script:Packages.final.url) { throw 'Unexpected download URL.' }
                Copy-Item -LiteralPath $script:FixtureFinalArchive -Destination $OutFile
            }
        } $FinalArchive
        try {
            $downloaded = Expand-LabContent -LabArchive $archive -StagingDirectory (Join-Path $testRoot 'downloaded')
            & $contentModule { param($Root) Assert-FinalSnapshot -Root $Root } (Join-Path $downloaded 'modules/module-03-execute/final/dotnet')
        }
        finally {
            & $contentModule { Remove-Item Function:Invoke-WebRequest; Remove-Variable FixtureFinalArchive -Scope Script }
        }
    }
    Test-Case 'A download failure is surfaced, not reported as an installed final' {
        & $contentModule { function script:Invoke-WebRequest { throw 'Fixture network unavailable' } }
        try {
            Assert-Throws { Expand-LabContent -LabArchive $archive -StagingDirectory (Join-Path $testRoot 'download-failed') } '*Fixture network unavailable*'
        }
        finally {
            & $contentModule { Remove-Item Function:Invoke-WebRequest }
        }
    }

    $setupScript = Join-Path $repositoryRoot 'scripts/setup.ps1'
    $destination = Join-Path $testRoot 'installed lab [1]'
    if ($IsWindows) {
        Test-Case 'The actual Windows setup installs content, README and four configs' {
            & $setupScript -LabArchive $archive -FinalArchive $FinalArchive -LabRoot $destination -SkipToolInstallation
            Assert-LabContent -Root $destination
            Assert-True ([IO.File]::ReadAllText((Join-Path $destination 'README-ORIGINAL.md')) -eq 'Original fixture entry point.') 'Original README not preserved.'
            foreach ($relative in @('modules/module-02-plan/start', 'modules/module-03-execute/start',
                'modules/module-02-plan/start/apps/CaldovaAuthGateway', 'modules/module-03-execute/start/apps/CaldovaAuthGateway')) {
                $config = Get-Content -LiteralPath (Join-Path $destination "$relative/.github/modernize/config.json") -Raw | ConvertFrom-Json
                Assert-True ($config.feature_flags.rulebook -eq $true) 'Rulebook flag missing.'
                Assert-True ($config.portfolio_url -eq 'https://github.com/ayangupt/ignite26-caldova-rulebook') 'Wrong rulebook source.'
            }
            Assert-True (@(Get-ChildItem -LiteralPath $testRoot -Directory -Force -Filter '.lab720-staging-*').Count -eq 0) 'Staging leaked after success.'
        }
        Test-Case 'A second setup refuses to overwrite an installed workspace' {
            Assert-Throws { & $setupScript -LabArchive $archive -FinalArchive $FinalArchive -LabRoot $destination -SkipToolInstallation } '*LabRoot already exists*'
        }
        Test-Case 'Failed Windows setup leaves no destination or staging directory' {
            $failedDestination = Join-Path $testRoot 'failed-install'
            Assert-Throws { & $setupScript -LabArchive $archive -FinalArchive $archive -LabRoot $failedDestination -SkipToolInstallation } '*SHA-256 mismatch*'
            Assert-True (-not (Test-Path -LiteralPath $failedDestination)) 'Failed setup left a destination.'
            Assert-True (@(Get-ChildItem -LiteralPath $testRoot -Directory -Force -Filter '.lab720-staging-*').Count -eq 0) 'Staging leaked after failure.'
        }
    }
    else {
        Test-Case 'Automatic tool setup explicitly rejects non-Windows platforms' {
            Assert-Throws { & $setupScript -LabArchive $archive -FinalArchive $FinalArchive -LabRoot $destination -SkipToolInstallation } '*supports Windows 11 only*'
            Assert-True (-not (Test-Path -LiteralPath $destination)) 'Unsupported setup wrote content.'
        }
        Write-Host 'NOT RUN: Windows setup integration cases. Run this same file on Windows.'
    }
    Write-Host "$script:passed checks passed. Fixture checks do not replace a real LAB720 archive/Windows 11 rehearsal."
}
finally {
    Remove-Module LabContent -ErrorAction SilentlyContinue
    Remove-Item -LiteralPath $testRoot -Recurse -Force
}
