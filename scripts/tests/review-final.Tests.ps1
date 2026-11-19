#requires -Version 5.1
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$root = Join-Path ([IO.Path]::GetTempPath()) "lab720-final-smoke-$([guid]::NewGuid().ToString('N').Substring(0, 8))"
$destination = Join-Path $root 'review'
$final = Join-Path $destination 'dotnet'
$output = Join-Path $root 'test-output'

try {
    & (Join-Path $PSScriptRoot '../review-final.ps1') -Destination $destination
    $before = @(Get-ChildItem -LiteralPath $final -Recurse -Force -File | Get-FileHash)
    $project = Join-Path $final 'apps/CaldovaAuthGateway/Tests/CaldovaAuthGateway.Tests.csproj'
    & dotnet test $project --configuration Release --artifacts-path $output -p:RestoreLockedMode=true `
        --results-directory $output --logger 'trx;LogFileName=final-gateway.trx'
    if ($LASTEXITCODE -ne 0) { throw "Final gateway tests failed (exit code $LASTEXITCODE)." }
    [xml]$trx = Get-Content -LiteralPath (Join-Path $output 'final-gateway.trx') -Raw
    $counts = $trx.SelectSingleNode("//*[local-name()='ResultSummary']/*[local-name()='Counters']")
    if (-not $counts -or [int]$counts.total -ne 13 -or [int]$counts.passed -ne 13 -or [int]$counts.failed -ne 0) {
        throw 'Expected exactly 13 passing final gateway tests.'
    }
    $after = @(Get-ChildItem -LiteralPath $final -Recurse -Force -File | Get-FileHash)
    if (Compare-Object $before $after -Property Path, Hash) { throw 'Tests changed the frozen final file set or contents.' }
    Write-Host 'PASS: Public download, 13 final gateway tests, and unchanged snapshot.'
}
finally {
    if (Test-Path -LiteralPath $root) { Remove-Item -LiteralPath $root -Recurse -Force }
}
