# Pipeline — Steward

How a change gets from a branch to the org, what protects each step, and how it was set up. Serves ST-13; decisions S-05, S-12, S-13, S-15 and S-17.

---

## The path of a change

```
feature branch ── pull request ──► Validate  (.github/workflows/validate.yml)
                                     1. Personal-details check: no real email address or username in force-app
                                     2. Formatting check (Prettier, code files only)
                                     3. Component tests (Jest), with an accessibility check in each
                                     4. Tests of the pipeline's own scripts
                                     5. Static analysis (Code Analyzer); critical or high findings stop it
                                     6. Sign in to the org as Steward CI (JWT)
                                     7. Check-only deployment with local Apex tests
                                     8. Coverage gate: every Steward class at 90% or more
                                     9. Job ID kept 10 days, only if everything above passed

               merge to main ────► Deploy  (.github/workflows/deploy.yml, only when force-app/ changed)
                                     1. Find the pull request behind the merge and its passing validation
                                     2. Quick-deploy that validation, with no second test run
                                     3. If Salesforce won't accept the quick deploy, deploy again with the same tests
                                     4. Publish the customer portal, when the pull request changed anything it shows

  run by hand ─────────────────────► Retrieve  (.github/workflows/retrieve.yml, S-15)
                                     1. Sign in as Steward CI and retrieve what a manifest lists
                                     2. Stop if the result holds a real email address or username
                                     3. Push the result to retrieve/<run number>; a pull request takes it to main
```

The `main` branch is protected by a ruleset: a pull request is required, the `validate` check has to pass, and the branch has to be up to date with `main` before merging. That last rule is what guarantees the commit that was validated is exactly what gets merged.

---

## What protects what

| Risk | Control |
|---|---|
| A change reaches the org untested | The ruleset requires a passing `validate` check. The deploy workflow refuses any change to `force-app/` that didn't arrive through a pull request with a passing validation |
| What merged isn't what was validated | "Require branches to be up to date before merging" |
| A key is committed to the repo | The key is generated outside the repo folder; `.gitignore` blocks `*.key`, `*.pem` and `*.crt`; push protection blocks known secret formats |
| A key leaks from a workflow run | The key is written to the runner's temporary folder and deleted straight after sign-in. GitHub doesn't give secrets to pull requests from forks |
| The pipeline's sign-in is misused | Only users with the `PS_Steward_CI` permission set can use the Steward CI app, and only one user has it. JWT only, refresh tokens expire after 90 days, sessions after 15 minutes |
| Two deployments collide | Deployments run one at a time (`concurrency: deploy-org`) |
| A class ships with thin tests | The coverage gate fails the pull request when any Steward class is below 90% on its own. A failed gate means the job ID isn't kept, so the merge has nothing to deploy |
| The coverage gate passes by mistake | It fails closed: a class the org reported no coverage for counts as 0%, and a result with no test data fails the check. The script has its own tests, run on every pull request |
| A broken pipeline change slips in | Workflow files go through pull requests like everything else, and each version is checked with actionlint before it's committed |
| A real person's details reach the public repo | The org fills some settings with the admin's own details, such as a new site's email sender and its admin. `scripts/check_personal_details.sh` fails on any email address or username not on a reserved example domain, before a retrieve pushes and on every pull request. It prints only the file and line, never the address, because the run logs of a public repo are public too |
| The portal doesn't show what was deployed | An LWR site serves the copy last published. The deploy publishes the portal when the pull request changed its pages, components, navigation or settings, and fails if publishing doesn't finish within 10 minutes |

## The coverage gate

The org's own rule is 75% coverage across all Apex. Steward's is stricter: every class and trigger in `force-app` at 90% or more, each on its own (ST-13, NFR-03).

`scripts/check_coverage.py` reads the coverage the org returns with the check-only deployment (`validate.json`, the `--json` output of `sf project deploy validate`). It finds every class and trigger in `force-app` and compares each with the gate. It skips test classes, interfaces and enums, which have nothing to cover, and an exception class with an empty body. It fails the step with one error per class below the gate and adds a coverage table to the run's summary page. It rounds down when it reports, so 89.96% shows as 89.9%, not a passing-looking 90.0%.

Its tests are in `tests/pipeline/test_check_coverage.py`. To run them locally from the repo root: `python -m unittest discover -s tests/pipeline -v`.

## The personal-details check

The repo is public, and the first retrieve of the portal site, on 2026-10-18, brought back the admin's own email address as the site's email sender and her username as its admin. They reached a pushed branch before anyone saw them. `scripts/check_personal_details.sh` now stops that happening again. It finds every email address or username under the folder it's given and fails unless each is on a reserved example domain (`example.com`, or a name ending in `.example`). It lists only where each one is.

It runs in two places: in `retrieve.yml`, before anything is pushed, and in `validate.yml`, so nothing personal can merge however it got onto a branch. Its tests are in `tests/pipeline/test_check_personal_details.py`. The settings it found now hold placeholders: the site's emails come from `portal@lumenfield.example`, and its admin is the Steward CI user.

## Publishing the portal

An LWR site serves the copy that was last published, so a deploy alone doesn't change what customers see. After a deploy, `deploy.yml` lists the pull request's files. If any is under the site bundle, the site's settings, its navigation or `lwc/`, it runs `sf community publish` for Lumenfield Customer Portal and waits for the background job to finish, checking `BackgroundOperation` every 15 seconds. The step fails if the job ends in an error or takes more than 10 minutes.

## Component tests

Jest runs every component's tests with `@salesforce/sfdx-lwc-jest`, and each test also runs an accessibility check with `@sa11y/jest` (`toBeAccessible`, NFR-05). Two pieces of setup in `jest/`:
- `setupLabels.js` reads the repo's custom labels and gives each component its real text, so tests check the words a customer reads, and a component that names a label that doesn't exist fails.
- `setupAccessibility.js` adds the accessibility check.

## Code Analyzer settings

The pipeline runs Code Analyzer's Recommended rules. Changes to the defaults live in `code-analyzer.yml` at the repo root, each with a comment giving the reason:
- `ApexUnitTestClassShouldHaveRunAs` is moved out of the default run: access tests run as a user created for the test, and business-logic tests run as the pipeline user on purpose, because no Salesforce license is free for a test admin.
- Jest tests are left out of the scan. They run in Node and are never deployed, and their documented patterns, such as waiting with `setTimeout`, break rules meant for component code.
- The site bundle is left out. Experience Builder writes it, and the next retrieve would undo any change.

Graph Engine, Code Analyzer's data-flow engine, isn't in the Recommended set; it's run by hand when entry points change (`sf code-analyzer run --rule-selector sfge`). On 2026-10-18 it reported two findings, both the S-08 commitments read: missing field-level and sharing checks, which is that decision's design, covered by `CommitmentReadServiceTest`.

## Retrieving what's built outside source

`retrieve.yml` brings configuration that didn't start in source into the repo (S-15). The first is the portal site: Salesforce's Build Your Own (LWR) template creates its pages, theme and settings.

1. On a branch, add or update a manifest in `manifest/` listing what to retrieve.
2. **Actions** → **Retrieve** → **Run workflow**. Choose that branch and enter the manifest's path.
3. The run signs in as Steward CI, retrieves, and pushes the files to `retrieve/<run number>`. If the repo already matches the org, it says so and pushes nothing.
4. Bring the files into a feature branch and open a pull request as usual. `validate` checks them like any other change.

## Secrets

Stored in GitHub: Settings → Secrets and variables → Actions.

| Secret | Holds |
|---|---|
| `SF_CLIENT_ID` | Consumer key of the Steward CI external client app |
| `SF_PRIVATE_KEY` | The private key that matches the certificate uploaded to the app |
| `SF_USERNAME` | The Steward CI user's username |
| `SF_INSTANCE_URL` | The org's My Domain URL |

## Known limits

- **One org.** Validation and deployment hit the same Developer Edition org. A team would validate against a UAT sandbox, then quick-deploy the same package to production.
- **Up-to-date rule and doc commits.** Committing docs straight to `main` puts any open pull request behind; it then needs **Update branch** and a fresh validation before it can merge.
- **Actions pinned to major versions** for readability. A stricter setup pins each action to a commit SHA.
- **Coverage measures lines run, not checks made.** A test can run a line without asserting anything about it. That's why NFR-03 also requires every test method to assert an outcome. Review enforces that, not the gate.
- **Graph Engine data-flow rules aren't run yet.** They start from entry points such as invocable and Aura-enabled methods, and Steward has none until the agent actions in Phase 6.
- **Agent releases.** Publishing and activating agent versions joins the deploy workflow in Phase 6 (S-10).

## Rotating the key

1. Generate a new key and certificate with the command in Part B below.
2. Upload the new certificate to the Steward CI app, under **Flow Enablement** in its OAuth settings.
3. Replace the `SF_PRIVATE_KEY` secret.
4. Delete the old key file.

---

## Setup — done once in Phase 2

**Part A — Einstein (1 minute).** Setup → Quick Find **Einstein Setup** → **Einstein Setup**. If **Turn on Einstein** is off, turn it on. Phases 5 and 6 need it.

**Part B — Key and certificate (3 minutes, PowerShell)**

1. Check that OpenSSL is available: `Test-Path "C:\Program Files\Git\usr\bin\openssl.exe"`. If it says `False`, run `winget install --id Git.Git -e`, then close and reopen PowerShell.
2. Make the key in its own folder, outside the repo:
   ```powershell
   New-Item -ItemType Directory -Force C:\Lumenfield-keys | Out-Null
   cd C:\Lumenfield-keys
   & "C:\Program Files\Git\usr\bin\openssl.exe" req -x509 -sha256 -nodes -days 730 -newkey rsa:2048 -keyout steward-ci.key -out steward-ci.crt -subj "/CN=Steward CI"
   ```
   `steward-ci.key` is the private key: it goes into one GitHub secret and nowhere else. `steward-ci.crt` is the certificate Salesforce gets. Both expire in two years.

**Part C — The pipeline user (5 minutes)**

1. Setup → Quick Find **Permission Sets** → **New**. Label `Steward CI`, API Name `PS_Steward_CI`, Description `Pre-authorizes the Steward CI user for the Steward CI external client app. Grants nothing else. ST-13, S-12.`, License **--None--** → **Save**. Nothing else to set.
2. Setup → Quick Find **Users** → **Users** → **New User**. First Name `Steward`, Last Name `CI`, Alias `stwci`, Email: yours, Username `steward.ci.lumenfield@example.com` (if it's taken, add a number), User License **Salesforce**, Profile **System Administrator**. Untick **Generate new password and notify user immediately**, since this user never signs in with a password. **Save**.
3. On the new user's page: **Permission Set Assignments** → **Edit Assignments** → add **Steward CI** → **Save**.

**Part D — External client app (5 minutes)**

1. Setup → Quick Find **App Manager** → **New External Client App**.
2. External Client App Name `Steward CI` (API name `Steward_CI`), Contact Email: yours, Distribution State **Local**.
3. Under **API (Enable OAuth Settings)**, tick **Enable OAuth**. Callback URL `http://localhost:1717/OauthRedirect`.
4. OAuth Scopes (they appear only after **Enable OAuth** is ticked, as two lists): move **Manage user data via APIs (api)**, **Manage user data via Web browsers (web)** and **Perform requests at any time (refresh_token, offline_access)** from **Available OAuth Scopes** to **Selected OAuth Scopes**. If the app already exists, add them from the **Settings** tab → **Edit**.
5. Under **Flow Enablement**, tick **Enable JWT Bearer Flow**, then **Upload Files** → `C:\Lumenfield-keys\steward-ci.crt`.
6. **Create**.
7. **Policies** tab → **Edit** → **OAuth Policies**: Permitted Users **Admin approved users are pre-authorized** (confirm with **OK**); under **App Policies**, select the **Steward CI** permission set; IP Relaxation **Relax IP restrictions**; Refresh Token Policy **Expire refresh token after specific time**, **90** **Day(s)** (the "if not used" option is capped at 30 days and won't save with 90); Session Timeout **15** minutes → **Save**. **Custom Scopes** on this tab is a different feature; leave it empty.
8. **Settings** tab → **OAuth Settings** → **Consumer Key and Secret** → enter the code emailed to you → **Copy** the Consumer Key.

**Part E — Test the sign-in from your computer (2 minutes).** In PowerShell, from `C:\Lumenfield-steward`. The first line asks you to paste the Consumer Key:
```powershell
$key = Read-Host "Paste the Consumer Key"
sf org login jwt --client-id $key --jwt-key-file C:\Lumenfield-keys\steward-ci.key --username steward.ci.lumenfield@example.com --instance-url https://orgfarm-27bf529dae-dev-ed.develop.my.salesforce.com --alias steward-ci
```
"client identifier invalid" means the Consumer Key is wrong or missing.
It should say the org was authorized. If it says the user hasn't approved this consumer, check the permission set assignment, wait 10 minutes for the app settings to take effect, and try again.

**Part F — GitHub secrets (4 minutes)**

1. The repo on github.com → **Settings** → **Secrets and variables** → **Actions** → **New repository secret**, four times: `SF_CLIENT_ID` (the consumer key), `SF_USERNAME` (the Steward CI username), `SF_INSTANCE_URL` (`https://orgfarm-27bf529dae-dev-ed.develop.my.salesforce.com`), and `SF_PRIVATE_KEY`. For the key, copy the whole file, including the BEGIN and END lines, with `Get-Content C:\Lumenfield-keys\steward-ci.key -Raw | Set-Clipboard`, then paste.
2. Push protection needs no setup: GitHub turns it on by default for every account, and it blocks known secret formats pushed to public repositories. (The repository-level setting didn't appear for this personal public repo on 2026-10-17.)

**Part G — The first pull request (5 minutes, then about 6 minutes of waiting)**

1. GitHub Desktop → **Current Branch** → **New Branch** → `feature/ST-13-pipeline` → **Create Branch**.
2. Extract the Phase 2 zip into `C:\Lumenfield-steward` and replace the files when asked.
3. Commit to the branch with the summary `ST-13: pipeline workflows and the first three policy settings`.
4. **Publish branch** → **Preview Pull Request** → **Create pull request**, then **Create pull request** again on GitHub.
5. On the pull request, the **validate** check runs. Wait for the green check.

**Part H — Protect `main`, then merge (3 minutes)**

1. **Settings** → **Rules** → **Rulesets** → **New ruleset** → **New branch ruleset**.
2. Ruleset Name `Protect main`; Enforcement status **Active**.
3. **Bypass list** → **Add bypass** → **Repository admin** → **Add selected**, left on **Always allow**, so docs can be committed straight to `main` (S-13).
4. **Target branches** → **Add target** → **Include default branch**.
5. Leave **Restrict deletions** and **Block force pushes** ticked. Tick **Require a pull request before merging** and leave required approvals at **0** (you can't approve your own pull request). Tick **Require status checks to pass before merging**, tick **Require branches to be up to date before merging**, then **Add checks** → type `validate` → select it.
6. **Create**.
7. On the pull request: **Merge pull request** → **Confirm merge**. The **Deploy** workflow starts on the **Actions** tab.
8. GitHub Desktop → **Current Branch** → **main** → **Fetch origin** → **Pull origin**.

**After the first deploy is confirmed in the org:** delete `C:\Lumenfield-keys\steward-ci.key`. GitHub holds the only copy it needs, and a new pair takes three minutes to make.
