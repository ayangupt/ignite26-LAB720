<a name="start-building"></a>

# LAB720: Modernize applications with GitHub Copilot
### Session description

Use GitHub Copilot modernization to review a prepared application assessment, create a rulebook-guided plan, start a modernization run, and validate the prepared .NET results. This repository focuses on the Caldova Bank application-modernization track.

### Lab walkthrough

This 50-minute lab covers assessment review, rulebook setup and planning, and validation of a prepared .NET modernization result. Live planning is optional; the guide keeps prepared evidence separate from current agent output.

The modernization section uses the shared [Caldova workshop rulebook](https://github.com/ayangupt/ignite26-caldova-rulebook). All learners use the same training baseline; creating an individual rulebook repository is not a prerequisite.

Follow the [modernization guide](instructions/modernize-app-code.md). The [attendee instructions](instructions/README.md) provide the track index.

<a id="getting-started"></a>

### 🚀 Getting started

#### Prerequisites

- Windows 11 with [winget](https://learn.microsoft.com/en-us/windows/package-manager/winget/). Install PowerShell 7 from Windows PowerShell if needed:

  ```powershell
  winget install --id Microsoft.PowerShell --exact --accept-package-agreements --accept-source-agreements
  ```

- A GitHub account with an active Copilot plan. The modernization agent supports Copilot Free, Pro, Pro+, Business, and Enterprise; see the [official quickstart](https://learn.microsoft.com/en-us/azure/developer/github-copilot-app-modernization/modernization-agent/quickstart) for current requirements.
- An authorized copy of the `caldova-rehearsal.zip` teaching archive. The archive and application source are not currently included in this repository; do not redistribute them without confirming their license.

The setup script installs Git, GitHub CLI, Visual Studio Code and its Copilot extensions, the .NET 10 SDK, and the Modernize CLI.

Clone this repository and run setup with the archive path:

```powershell
pwsh -NoProfile -File .\scripts\setup.ps1 -LabArchive C:\path\to\caldova-rehearsal.zip
```

If you downloaded this repository as a ZIP instead of cloning it, run `Get-ChildItem -Recurse .\scripts | Unblock-File` first so PowerShell can run the scripts.

By default, the lab files are installed under `C:\lab\caldova`, matching the guide's paths. Choose another destination with `-LabRoot`; if you do, use that same path in place of `C:\lab\caldova` in the guide. Setup will not overwrite an existing lab folder. After installation, open a new PowerShell terminal and sign in:

```powershell
gh auth login
```

Sign in to VS Code with the same account, then verify setup:

```powershell
pwsh -NoProfile -File .\scripts\verify.ps1
```

The rulebook source is public, but planning and execution require your account's Copilot entitlement.

#### In a guided session

If you're following along during a live session:

1. Use the prepared lab files and assigned account supplied for the session, or run the setup steps above on your own Windows machine.
2. Sign in to `gh` and VS Code with the same GitHub account, then verify the setup.
3. Follow the [modernization guide](instructions/modernize-app-code.md). Work through live planning and plan review, then use the prepared execution checkpoint and code for review and validation.

#### On your own

If you're learning at your own pace:

1. Clone the repository and run setup with an authorized archive as described above.
2. Run the verification script, authenticate with GitHub CLI and VS Code, then follow [Modernize application code with GitHub Copilot](instructions/modernize-app-code.md).

### 🎯 Learning outcomes

By the end of this session, you will be able to:

- Identify upgrade, security, cloud-readiness, and database-connection risks from a prepared application-estate assessment.
- Start a rulebook-guided modernization plan and execution with GitHub Copilot, then review and test prepared .NET results for database-access changes, personal-data masking, and compatibility, recording what remains unverified.

### 💻 Technologies used

- [GitHub Copilot](https://learn.microsoft.com/en-us/azure/developer/github-copilot-app-modernization/) and the [`modernize` CLI](https://learn.microsoft.com/en-us/azure/developer/github-copilot-app-modernization/modernization-agent/cli-commands)
- [Visual Studio Code](https://code.visualstudio.com/docs) and [PowerShell](https://learn.microsoft.com/en-us/powershell/scripting/overview)
- [.NET 10](https://learn.microsoft.com/en-us/dotnet/core/whats-new/dotnet-10/overview) and [ASP.NET Core](https://learn.microsoft.com/en-us/aspnet/core/overview?view=aspnetcore-10.0)
- [`Microsoft.Data.SqlClient`](https://learn.microsoft.com/en-us/sql/connect/ado-net/introduction-microsoft-data-sqlclient-namespace?view=sql-server-ver17) and [managed identity](https://learn.microsoft.com/en-us/sql/connect/ado-net/sql/azure-active-directory-authentication?view=sql-server-ver17) for application-side database access
- [Azure Container Apps](https://learn.microsoft.com/en-us/azure/container-apps/overview) (modernization target)

### 📚 Official documentation

- [GitHub Copilot modernization quickstart](https://learn.microsoft.com/en-us/azure/developer/github-copilot-app-modernization/modernization-agent/quickstart)
- [Modernize CLI commands](https://learn.microsoft.com/en-us/azure/developer/github-copilot-app-modernization/modernization-agent/cli-commands)
- [ASP.NET Core documentation](https://learn.microsoft.com/en-us/aspnet/core/overview?view=aspnetcore-10.0)

### 👥 Content owners

<table>
<tr>
    <td align="center"><a href="https://github.com/ayangupt">
        <img src="https://avatars.githubusercontent.com/u/74832088?v=4" width="100px;" alt="Ayan Gupta"/><br />
        <sub><b>Ayan Gupta</b></sub></a><br />
        <sub>GitHub Copilot modernization</sub>
    </td>
</tr></table>

### ⚖️ Trademarks

This project may contain trademarks or logos for projects, products, or services. Authorized use of Microsoft trademarks or logos is subject to and must follow [Microsoft's Trademark & Brand Guidelines](https://www.microsoft.com/legal/intellectualproperty/trademarks/usage/general). Use of Microsoft trademarks or logos in modified versions of this project must not cause confusion or imply Microsoft sponsorship.

Any use of third-party trademarks or logos are subject to those third-party's policies.
