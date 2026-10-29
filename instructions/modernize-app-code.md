# Modernize application code with GitHub Copilot

**Goal:** Read an application estate assessment, create a rulebook-guided plan, and check modernized code rather than trusting a successful agent response.

| Stage | Time | Your result |
|---|---|---|
| Assess | 8 minutes | Assessment read and the provider's database risks identified |
| Plan | 12 minutes | A live plan started and the prepared plan reviewed against the rulebook |
| Execute and verify | 25 minutes | An execution started and a prepared result built, tested, and checked |

This lab uses the **.NET track** of the Caldova Bank training estate. Each module has a `start` folder (before) and a `finish` folder (after) under `C:\lab\caldova\modules`. You start the slow agent steps, then review the prepared result instead of waiting.

**Expected result:** You can explain what changed, show the checks you performed, and identify anything not yet verified.

**If blocked:** Use the prepared `finish` folders and ask the facilitator. Do not install tools, create resources, or switch to personal accounts.

---

## Get ready

### Do this

1. Select the lab VM and sign in to Windows with the credentials on the **Resources** tab.
2. Open Windows Terminal with **PowerShell inside the VM** and check the existing sessions:

   ```powershell
   gh auth status
   Test-Path C:\lab\caldova\modules\module-01-assess\start
   ```

3. If GitHub sign-in is missing, open `https://github.com/enterprises/skillable-events/sso` **inside the VM**. Use the **Resources > Azure Portal** username and TAP keyboard controls in the matching Microsoft sign-in fields. Do not enter the Azure password into GitHub's standard password form. Then run `gh auth login` and use **Sign In > Continue with GitHub** in VS Code with the same browser session. Use the assigned lab account, not a personal GitHub account.

**Expected result:** `gh auth status` succeeds and the folder check returns `True`. Use **Auto** as the model unless the facilitator tells you otherwise.

---

## 1. Read the assessment

**Goal:** Understand the estate and find the provider's database risks. The assessment has already been run for you; a live run takes longer than this lab allows.

### Do this

1. Open the assessment inputs to see what was assessed and how:

   ```powershell
   cd C:\lab\caldova\modules\module-01-assess\start
   Get-Content .github\modernize\repos-live.json
   Get-Content .github\modernize\assess-config.yaml
   ```

   The supplied inputs select `CaldovaAuthGateway`, use **Full analysis**, and target .NET 10 on Azure Container Apps. The prepared portfolio below is an earlier estate-wide assessment, not output from these current inputs. The command for a new assessment is in **Reference**; do not run it during this shortened lab.

2. In File Explorer, open the prepared report:

   ```plaintext
   C:\lab\caldova\modules\module-01-assess\start\.github\modernize\assessment-prebuilt\reports-<timestamp>\index.html
   ```

   Open the actual `reports-...` folder; do not type `<timestamp>` literally. If Windows asks which app to use for `index.html`, select **Microsoft Edge > Just once**.

3. Review the portfolio, then open `repos\ZavaAuthGateway` inside that report folder. The supplied historical report retains the original **Zava** names; the working application is now called **CaldovaAuthGateway**. Do not rename the report files. Identify unsupported frameworks, security findings, and cloud-readiness issues.
4. In that gateway report folder, open `facts\data-architecture.md` and `facts\configuration-inventory.md`. Find `System.Data.SqlClient`, SQL-login settings (`DB_USER`/`DB_PASSWORD`), and certificate-validation settings.

These are findings about how the application uses a database, not checks against a running database. An inferred data model does not confirm that tables or seed data exist, that a connection works, or that a migration has completed.

**Expected result:** You can explain why `CaldovaAuthGateway` is modernized first: `CaldovaLoanPortal` signs in through it. You can name the database authentication changes the plan must cover.

**Checkpoint:** Provider identified and its database connection risks listed.

---

## 2. Load the rulebook and add the PII skill

**Goal:** Give planning and execution the same rules, plus a method for keeping personal data out of logs.

### Do this

1. Open `C:\lab\caldova\modules\module-02-plan\start`. Skim `rulebook\policies.md` and `rulebook\targets.md`. The policy requires managed identity, certificate validation, no personal data in logs, supported dependencies, health checks, and Azure Container Apps readiness.
2. Open `.github\modernize\config.json` and check that `feature_flags.rulebook` is `true` and `portfolio_url` points to the repository supplied for the lab's rulebook setup. Do not invent a URL or create a repository unless the facilitator provides that setup procedure.
3. Copy the PII masking skill into the gateway:

   ```powershell
   cd C:\lab\caldova\modules\module-02-plan\start
   New-Item -ItemType Directory -Force -Path apps\CaldovaAuthGateway\.github\skills | Out-Null
   Copy-Item skills\pii-masking apps\CaldovaAuthGateway\.github\skills\ -Recurse
   ```

**Expected result:** `apps\CaldovaAuthGateway\.github\skills\pii-masking` exists.

The bank policy and rulebook are workshop examples, not approved organizational policy.

**If blocked:** If the configuration is missing, the rulebook feature is disabled, or repository access is unavailable, tell the facilitator. Skip live planning and execution; start with item 4 of step 3 to review the prepared plan, then continue to the code review in step 5. Run step 6 only if the .NET SDK and package access are available. Record skipped runs and central-rulebook loading as **not verified**; reading local policies is not proof that the CLI loaded them.

---

## 3. Start the plan, then review the prepared plan

**Goal:** Start a live plan, and while it runs, check the prepared plan against the rulebook.

### Do this

1. Copy the goal:

   ```powershell
   cd C:\lab\caldova\modules\module-02-plan\start
   Get-Content goals\dotnet.txt -Raw | Set-Clipboard
   ```

2. Run `modernize`. Select **Plan > Create modernization plan > Keep the plan local**. Select `CaldovaAuthGateway`, name the plan `caldova-dotnet-modernization`, and paste the goal. Answer clarifying questions using the rulebook.
3. Look for **`Rulebook loaded (3 files)`**. Leave the run open and continue.
4. Leave any live planning run open. In another PowerShell terminal, select the prepared branch before opening the plan in VS Code:

   ```powershell
   cd C:\lab\caldova\modules\module-03-execute\start
   git switch modernization/dotnet
   code apps\CaldovaAuthGateway
   ```

   The prepared plan is on `modernization/dotnet`, not `main`. In Explorer, open `.github > modernize > caldova-dotnet-modernization > plan.md` and use **Open Preview**. Also open `.metadata\tasks.json` and `rulebook-compliance.md`.

5. Match each requirement to a task. Treat the compliance report as a lead, not proof.

   - **Supported runtime:** .NET 10, SDK-style project.
   - **Passwordless database access:** Managed identity; stored SQL credentials removed.
   - **Validated TLS:** `Encrypt=True` and `TrustServerCertificate=False`.
   - **No personal data in logs:** Structured logging with the `pii-masking` skill.
   - **Supported libraries:** `System.Data.SqlClient` replaced; vulnerabilities scanned.
   - **Preserved behavior:** Public routes and the `/WhoAmI.ashx` sign-in contract.
   - **Deployable result:** Health endpoint, environment-based settings, compliant Dockerfile.

**Expected result:** Every requirement maps to a task, and `pii-masking` appears on the logging task. Your live plan, if it finishes, should show the same coverage; wording and task counts can differ.

**If blocked:** If the live plan stalls, keep reviewing the prepared plan and record the run as pending. If the rulebook load message is missing, tell the facilitator and do not start execution on the assumption that the policies were applied.

**Checkpoint:** Prepared plan reviewed against the rulebook.

---

## 4. Start the prepared execution

**Goal:** Start agent work on a prepared branch, then review a finished result while it runs.

The `modernization/dotnet` branch is already prepared with the PII skill and the reviewed plan.

### Do this

1. Close the live planning run if it is still going. In PowerShell:

   ```powershell
   cd C:\lab\caldova\modules\module-03-execute\start
   git switch modernization/dotnet
   git --no-pager log --oneline
   ```

2. In `tasks.json`, confirm the first two tasks (runtime upgrade and Web Forms conversion) show `"status": "success"`.
3. Check `.github\modernize\config.json` in this execution module's working directory as in step 2. Do not assume the planning module's configuration applies here. If the rulebook setup is unavailable, skip this live run and continue to step 5. Otherwise, start the remaining tasks from PowerShell:

   ```powershell
   modernize plan execute "Execute all remaining tasks, starting with the first unfinished task. Do not stop after one task. Do not run the deployment task." `
     --plan-name caldova-dotnet-modernization `
     --source apps\CaldovaAuthGateway `
     --no-tty
   ```

4. Confirm **`Rulebook loaded (3 files)`** appears. Leave the terminal open and continue. **Do not wait for the run to finish.**

**Expected result:** The agent works on the database, logging/PII, and validation tasks.

**If blocked:** If the task state is not as expected, ask the facilitator. Do not start a second execution while the first is active.

---

## 5. Review a finished application

**Goal:** Tell the difference between a successful transformation and one that actually follows the rules.

### Do this

1. Leave any live execution running and open another PowerShell terminal:

   ```powershell
   cd C:\lab\caldova\modules\module-03-execute\finish
   git switch modernization/dotnet
   git --no-pager diff --stat main -- apps/CaldovaLoanPortal
   ```

2. Find the ASP.NET Core replacement for the old Web Forms code. Inspect the database configuration and public routes.
3. Find at least two gaps against the rulebook:
   - Look for the legacy `FROM mono:6.12` base image in the Dockerfile.
   - Check how the portal recognizes a user signed in through the gateway's `/WhoAmI.ashx`.

4. Spend about four minutes on the separately prepared final state:

   ```powershell
   code C:\lab\caldova\modules\module-03-execute\final\dotnet
   ```

   Confirm all three applications target .NET 10, compare the portal's Microsoft-based non-root Dockerfile with the review example, and read `VALIDATION.md`. This is prepared evidence, not the output of your live run. Do not rerun the full SQL-backed suite during this lab.

**Expected result:** You can explain the review gaps and how the validated final state addresses them. Distinguish local tests and container checks from the Azure and central-rulebook checks that remain unverified. The intentionally flawed finish example remains useful; the final state complements it rather than replacing it.

---

## 6. Validate the provider

**Goal:** Build, test, and run the prepared gateway, then apply the same checks to your own run if it finishes.

### Do this

1. Build the prepared gateway and run its tests:

   ```powershell
   cd C:\lab\caldova\modules\module-03-execute\finish\apps\CaldovaAuthGateway
   dotnet build
   dotnet test Tests\CaldovaAuthGateway.Tests.csproj
   ```

2. Check these gates in the code:

   | Gate | Expected evidence |
   |---|---|
   | Runtime and build | SDK-style .NET 10 project; build succeeds |
   | Database code | `Microsoft.Data.SqlClient` with identity-based authentication; no stored password; validated TLS; `DB_HOST`/`DB_NAME` settings |
   | PII | Masking helper used by structured logs; tests check raw personal data is absent |
   | Compatibility | Public routes and response contracts preserved |

3. Run the gateway locally without a database:

   ```powershell
   $env:DB_HOST = 'localhost'
   $env:DB_NAME = 'CaldovaBankDB'
   $env:APPLICATIONINSIGHTS_CONNECTION_STRING = 'InstrumentationKey=00000000-0000-0000-0000-000000000000;IngestionEndpoint=http://localhost/'
   dotnet run
   ```

4. In a second terminal, check the routes:

   ```powershell
   curl.exe -i http://localhost:8080/health
   curl.exe -i http://localhost:8080/WhoAmI.ashx
   ```

   Expect HTTP 200, and `{"authenticated":false}` from `/WhoAmI.ashx`. Stop the app with **Ctrl+C**.

5. If you started a live execution, return to it. If it finished, repeat these checks on `module-03-execute\start\apps\CaldovaAuthGateway`; if it is still running, record it as pending. If you skipped execution, record it as not started.

**Expected result:** You have build and test evidence and a compatibility check. These local checks do not prove Azure SQL access, signed-in behavior, or telemetry delivery.

---

## Finish

### Check your outcome

Mark only the outcomes you completed. Distinguish your own live runs from the supplied artifacts, and record each skipped or unfinished run as **not started** or **pending**. The review-only fallback does not complete the full hands-on exercise.

- You identified the provider and its database risks from the assessment.
- You checked the plan against the rulebook and confirmed the PII skill is used.
- You started a scoped execution on the prepared branch.
- You built and tested a prepared result and recorded the gaps and unverified checks.

If your agent is still running, note its pending tasks. Do not start duplicates or reset the lab.

### If something did not work

| Symptom | Next action |
|---|---|
| Lab folders, tool, or model missing | Ask the facilitator; do not install or switch to personal access |
| No `Rulebook loaded (3 files)` message | Check the working directory, feature flag, and `gh auth status`; tell the facilitator |
| Planning or execution takes too long | Use the prepared plan or result and record the live run as pending |
| Build passes but sign-in fails | Inspect the gateway/portal authentication contract |

---

## Reference

These are not additional required steps.

### Running a new assessment

Run from `module-01-assess\start`:

```powershell
modernize assess `
  --source "$PWD\.github\modernize\repos-live.json" `
  --assess-config "$PWD\.github\modernize\assess-config.yaml" `
  --output-path "$PWD\.github\modernize\assessment" `
  --no-tty
```

### Planning from PowerShell

Run from `module-02-plan\start`:

```powershell
modernize plan create (Get-Content goals\dotnet.txt -Raw) `
  --source apps\CaldovaAuthGateway `
  --plan-name caldova-dotnet-modernization `
  --language dotnet `
  --no-tty
```

### The estate

- **CaldovaAuthGateway:** Web Forms/handlers on .NET Framework 4.8; sign-in provider.
- **CaldovaLoanPortal:** Web Forms on .NET Framework 4.8; signs in through the gateway.
- **CaldovaRiskEngine:** WCF on .NET Framework 4.8; credit-scoring service.
- **CaldovaLedger:** Servlets on Java 17; Java estate, not used in this lab.
- **CaldovaPayGateway:** Struts 1.3.10 on Java 8; Java estate, not used in this lab.
- **CaldovaFraudDetector:** Struts 2.5.30 on Java 11; Java estate, not used in this lab.

The full version of this exercise, including the Java track and live assessment, is in the PREL38 pre-day lab.
