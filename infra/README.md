# Infrastructure

For the self-serve modernization track, `../scripts/setup.ps1` installs the participant tools, prepares the learner-supplied **LAB720** archive, installs the separate frozen final checkpoint and [lab-root-README.md](lab-root-README.md), and copies the shared rulebook configuration into the actual CLI launch directories. LAB720's current 50-minute guide is the baseline; PREL38 is not a replacement track.

## Teaching packages and release gate

The [LAB720 environment handoff](https://github.com/microsoft/ignite26-lab-management/issues/689) identifies **two distinct ZIPs**, pinned by SHA-256 in [workload-manifest.json](workload-manifest.json):

| Package | Purpose | Source |
|---|---|---|
| `caldova-rehearsal.zip` | Six original assessment/planning/execution start/finish repositories, including Git history and prepared branches | Authorized local copy required; no approved public distribution location is configured |
| `part2-validated-final-dotnet-20261027.zip` | Separate frozen three-application comparison checkpoint | Automatically downloaded from a commit-pinned public package, or supplied with `-FinalArchive` |

The public final package is hosted in PREL38, but its hash is the exact hash recorded for LAB720. Setup never substitutes it for the original teaching modules. Both archives are checked before extraction; the final manifest and all 84 listed files are also checked. The module repositories remain separate from `final\dotnet`.

The historical handoff records successful LAB720 image checks, not a clean-machine test of this repository's installer. **Public clone-and-run readiness remains blocked** until the original workload has an approved source and the actual setup is rehearsed on Windows 11. Do not publish the historical code/report archive merely because the final package is public.

Before calling the self-serve track ready:

- Establish an approved distribution path for the real LAB720 starting archive and confirm it contains every artifact referenced by the current guide.
- Rehearse installation on a clean Windows 11 machine, including tool installation, user sign-in, prepared branch/task state, and planning/execution rulebook loading.
- Run the prepared gateway's build, 13 tests and local route checks from the LAB720 guide. Keep database-backed login, Azure and SRE outside this scope.
- Record any compatibility changes needed for current tools. The historical successful image used Modernize 1.0.62, GitHub CLI 2.90.0 and .NET SDK 10.0.403; those historical versions do not establish that the current installers work.

## Modernization rulebook configuration

The [participant guide](../instructions/modernize-app-code.md) uses the same public [Caldova workshop rulebook](https://github.com/ayangupt/ignite26-caldova-rulebook) as PREL38. Learners do not need to publish individual policy repositories.

The finalized training baseline is **1.0**, commit `5564f81d46c25830910e44dea27a32f32720dabc`. This is workshop policy, not production-policy approval.

### Prepare the launch directories

Use [modernize-config.json](modernize-config.json) as the content of `.github\modernize\config.json` in each actual launch directory:

- `C:\lab\caldova\modules\module-02-plan\start`
- `C:\lab\caldova\modules\module-03-execute\start`

The shortened lab starts the CLI at those module roots. If the image also supports launching Modernize from VS Code or an application directory, the gateway app root in each module needs the same config:

- `C:\lab\caldova\modules\module-02-plan\start\apps\CaldovaAuthGateway`
- `C:\lab\caldova\modules\module-03-execute\start\apps\CaldovaAuthGateway`

Setup first selects `main` for planning-start and `modernization/dotnet` for execution-start and execution-finish, then copies the configs. It requires the extracted repositories to be clean, preserves their refs and does not execute archived Git hooks. This prepares the branch selection that the current guide assumes has already happened.

Keep the config available after selecting the prepared branch. Inspect existing configuration and authored work before changing it; do not reset repositories or overwrite a learner's plan. Local `rulebook\charter.md`, `policies.md` and `targets.md` in the planning workspace should be reading copies of the shared baseline.

Do not alter the deliberately flawed `finish` review example or the frozen `final\dotnet` files, rulebook copies and manifest to make historical evidence appear newly validated.

### Install the LAB720 entry point

The setup script installs [lab-root-README.md](lab-root-README.md) as `README.md` at the extracted workload root. If the authorized archive already has a root `README.md`, setup renames it to `README-ORIGINAL.md` in the installed copy; it does not modify the source archive. The replacement links to the repository's self-serve guide and describes the 50-minute modernization flow: 5 minutes for setup/transitions, 8 for assessment, 17 for rulebook setup and planning, and 20 for execution and validation.

This repository setup does not update an existing shared VM image. If the lab continues to be offered from a managed image, an authorized guest-file update and image capture are still required for future launches to receive the new entry point.

### Verify a self-serve install

Run `scripts/verify.ps1` from the cloned repository after setup and sign-in. Pass the same `-LabRoot` if you used a nondefault destination. It checks the teaching-file layout, frozen-final manifest/hashes, required local commands, GitHub CLI authentication, .NET 10, Modernize CLI availability, four launch-directory configs, and exactly 13 passing prepared-gateway tests. Failed test results are retained at the printed temporary path for diagnosis. These checks do not prove that a live Modernize operation can access the shared rulebook; on a fresh install, confirm that both planning and execution report **`Rulebook loaded (3 files)`**.

The self-serve track validates application code locally. It does not provision Azure SQL, deploy applications or require cloud resources. If the lab is also offered from an existing managed VM image, this repository setup does not update that image; an authorized guest-file update and image capture are still required.

## Repeatable script checks

With PowerShell 7 and Git installed, run:

```powershell
pwsh -NoProfile -File .\scripts\tests\content.Tests.ps1
```

The checks use synthetic repositories and the real public final package. Supply `-FinalArchive` to reuse a downloaded copy without network access. No Pester or private workload download is required. Only the expected rehearsal digest is replaced in the test process; production scripts are loaded unchanged.

These checks cover two-package extraction, hash failures, final-file/manifest tampering, preservation of Git refs, prepared branch selection, missing guide inputs, dirty-workspace refusal and download failures. On Windows they also invoke the actual setup with `-SkipToolInstallation` and check configuration placement, non-overwrite behavior and cleanup. The GitHub Actions workflow runs on Windows and Linux; Windows Server fixture checks are **not** a clean Windows 11 tool-installation or real-workload rehearsal.
