# Pipeline — Steward

How a change gets from a branch to the org, what protects each step, and how it was set up. Serves ST-13; decisions S-05, S-12 and S-13.

---

## The path of a change

```
feature branch ── pull request ──► Validate  (.github/workflows/validate.yml)
                                     1. Formatting check (Prettier, code files only)
                                     2. Component tests (Jest), once components exist
                                     3. Static analysis (Code Analyzer); critical or high findings stop it
                                     4. Sign in to the org as Steward CI (JWT)
                                     5. Check-only deployment with local Apex tests; job ID kept 10 days

               merge to main ────► Deploy  (.github/workflows/deploy.yml, only when force-app/ changed)
                                     1. Find the pull request behind the merge and its passing validation
                                     2. Quick-deploy that validation, with no second test run
                                     3. If Salesforce won't accept the quick deploy, deploy again with the same tests
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
| A broken pipeline change slips in | Workflow files go through pull requests like everything else. The first versions were checked with actionlint |

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
- **Coverage gate.** The 90% per-class coverage check (ST-13) arrives with the first Apex class in Phase 3.
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
4. OAuth Scopes: add **Manage user data via APIs (api)**, **Manage user data via Web browsers (web)** and **Perform requests at any time (refresh_token, offline_access)**.
5. Under **Flow Enablement**, tick **Enable JWT Bearer Flow**, then **Upload Files** → `C:\Lumenfield-keys\steward-ci.crt`.
6. **Create**.
7. **Policies** tab → **Edit** → **OAuth Policies**: Permitted Users **Admin approved users are pre-authorized** (confirm with **OK**); under **App Policies**, select the **Steward CI** permission set; IP Relaxation **Relax IP restrictions**; Refresh Token Policy **Expire refresh token after specific time**, **90** **Day(s)**; Session Timeout **15** minutes → **Save**.
8. **Settings** tab → **OAuth Settings** → **Consumer Key and Secret** → enter the code emailed to you → **Copy** the Consumer Key.

**Part E — Test the sign-in from your computer (2 minutes).** In PowerShell, from `C:\Lumenfield-steward`:
```powershell
sf org login jwt --client-id PASTE_CONSUMER_KEY --jwt-key-file C:\Lumenfield-keys\steward-ci.key --username steward.ci.lumenfield@example.com --instance-url https://orgfarm-27bf529dae-dev-ed.develop.my.salesforce.com --alias steward-ci
```
It should say the org was authorized. If it says the user hasn't approved this consumer, check the permission set assignment, wait 10 minutes for the app settings to take effect, and try again.

**Part F — GitHub secrets and push protection (4 minutes)**

1. The repo on github.com → **Settings** → **Secrets and variables** → **Actions** → **New repository secret**, four times: `SF_CLIENT_ID` (the consumer key), `SF_USERNAME` (the Steward CI username), `SF_INSTANCE_URL` (`https://orgfarm-27bf529dae-dev-ed.develop.my.salesforce.com`), and `SF_PRIVATE_KEY`. For the key, copy the whole file, including the BEGIN and END lines, with `Get-Content C:\Lumenfield-keys\steward-ci.key -Raw | Set-Clipboard`, then paste.
2. **Settings** → **Advanced Security** → **Enable** next to Secret Protection if it's off, then **Enable** next to **Push protection**.

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
