# Infrastructure

For the self-serve modernization track, `../scripts/setup.ps1` installs the participant tools, prepares the learner-supplied Caldova archive, replaces its PREL38 root README with [lab-root-README.md](lab-root-README.md), and copies the shared rulebook configuration into the actual CLI launch directories. The archive is not included in this repository; setup requires an authorized local copy.

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

Keep the config available after selecting the prepared `modernization/dotnet` branch. Inspect existing configuration and authored work before changing it; do not reset repositories or overwrite a learner's plan. Local `rulebook\charter.md`, `policies.md` and `targets.md` in the planning workspace should be reading copies of the shared baseline.

Do not alter the deliberately flawed `finish` review example or the frozen `final\dotnet` files, rulebook copies and manifest to make historical evidence appear newly validated.

### Install the LAB720 entry point

The setup script installs [lab-root-README.md](lab-root-README.md) as `README.md` at the extracted workload root. If the authorized archive already has a root `README.md`, setup renames it to `README-PREL38.md` in the installed copy; it does not modify the source archive. The replacement links to the repository's self-serve guide and describes the 50-minute modernization flow: 5 minutes for setup/transitions, 8 for assessment, 17 for rulebook setup and planning, and 20 for execution and validation.

This repository setup does not update an existing shared VM image. If the lab continues to be offered from a managed image, an authorized guest-file update and image capture are still required for future launches to receive the new entry point.

### Verify a self-serve install

Run `scripts/verify.ps1` from the cloned repository after setup and sign-in. It checks the required local commands, GitHub CLI authentication, .NET 10, Modernize CLI availability, the four launch-directory configs, and the prepared gateway tests. These checks do not prove that a live Modernize operation can access the shared rulebook; on a fresh install, confirm that both planning and execution report **`Rulebook loaded (3 files)`**.

The self-serve track validates application code locally. It does not provision Azure SQL, deploy applications or require cloud resources. If the lab is also offered from an existing managed VM image, this repository setup does not update that image; an authorized guest-file update and image capture are still required.
