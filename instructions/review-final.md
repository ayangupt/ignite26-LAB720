# Review the public LAB720 final checkpoint

If you have the repository but not the original teaching archive, you can still inspect the three .NET applications from [step 5 of LAB720](modernize-app-code.md#compare-with-the-final-snapshot). This is a review of the **final** code, not a modernization run. It does not include the assessment, prepared plan, task history or deliberately flawed `finish` example.

## Get the checkpoint

Clone this repository or download and extract its source ZIP. From the repository root, run this in **Windows PowerShell** (included with Windows 11):

```powershell
powershell.exe -NoProfile -ExecutionPolicy RemoteSigned -File .\scripts\review-final.ps1
```

If Windows marked the source ZIP as downloaded, review the scripts and run `Get-ChildItem .\scripts -File -Recurse | Unblock-File` first. In PowerShell 7 on macOS, Linux or Windows, use `pwsh -NoProfile -File ./scripts/review-final.ps1` instead.

The script downloads the [pinned LAB720 final ZIP](../infra/workload-manifest.json), checks its SHA-256, then checks the manifest and all 84 listed files before moving them into `$HOME/lab720-final-review/dotnet`. It installs no tools and needs no account. To use a previously downloaded copy, pass `-FinalArchive` and its path. To choose another location, pass `-Destination` and a **new** directory name; an existing destination is never overwritten.

## Inspect the modernization decisions

Open the printed `dotnet` directory in any editor. All paths below are relative to that directory.

| Open | What to check |
|---|---|
| The application `.csproj` in each of `apps/CaldovaAuthGateway`, `apps/CaldovaLoanPortal` and `apps/CaldovaRiskEngine` | Each targets `net10.0`. The target framework tells you where the code runs, not whether the apps still work together. |
| `apps/CaldovaAuthGateway/DbConfig.cs` | Find `ActiveDirectoryDefault`, `Encrypt = SqlConnectionEncryptOption.Mandatory` and `TrustServerCertificate = false`. The gateway uses identity-based SQL authentication and requires an encrypted connection with certificate validation. Reading this code does not establish a live SQL connection. |
| `apps/CaldovaLoanPortal/Dockerfile` | Compare the .NET 10 SDK build image with the ASP.NET 10 runtime image. Find `USER $APP_UID` in the runtime stage. No container build is needed for this review. |
| `VALIDATION.md` | Compare **Observed results** with **Still environment-dependent**. Which checks ran in the original rehearsal? Which, such as Azure SQL managed identity, were not exercised? Neither set is evidence from your machine. |

## Optional: test the final gateway on your machine

You need the [.NET 10 SDK](https://dotnet.microsoft.com/download/dotnet/10.0) and access to NuGet.org for the first restore. On Windows, you can install the SDK with `winget install --id Microsoft.DotNet.SDK.10 --exact`. In a new PowerShell terminal, run:

```powershell
$final = Join-Path $HOME 'lab720-final-review/dotnet'  # Adjust if you used -Destination.
$project = Join-Path $final 'apps/CaldovaAuthGateway/Tests/CaldovaAuthGateway.Tests.csproj'
$output = Join-Path ([IO.Path]::GetTempPath()) "lab720-final-tests-$([guid]::NewGuid())"
dotnet test $project --configuration Release --artifacts-path $output -p:RestoreLockedMode=true
```

Expect **13 passed, 0 failed, 0 skipped**. Build output goes outside the frozen snapshot. These are your local **final gateway** results, not the historical full-suite results or the prepared-`finish` gateway validation in [step 6 of the full lab](modernize-app-code.md#6-validate-the-prepared-gateway). No SQL database, Docker, Modernize CLI or Copilot subscription is required.
