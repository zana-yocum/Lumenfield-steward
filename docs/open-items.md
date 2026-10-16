# Open Items — Steward

Everything deferred, flagged or half-finished. Updated at the end of every sitting. Nothing gets to live only in a chat log or someone's memory.

**Status key:** ☐ open · ☑ done · ⊘ deliberately not doing

---

## Phase 1 — Requirements — 2026-10-16

- ☑ Org facts read for the stories: policy settings, dispute evidence (16 records), statuses and types, record types, fields on the five Accord objects, Case, Account and Service Contract
- ☑ `docs/requirements.md` (18 stories), `docs/decision-log.md` (S-01 to S-11), `docs/conventions.md`, `docs/brief.md`
- ☑ Phase 2 readiness checked (see Found in the org)

**Your steps** (about 10 minutes)
- ☐ In File Explorer, create the folder `C:\Lumenfield-steward`
- ☐ Right-click `steward-phase1.zip` → **Extract All** → **Browse** → `C:\Lumenfield-steward` → **Extract**. `README.md`, `docs` and `sfdx-project.json` should sit directly inside `C:\Lumenfield-steward`, not inside a second folder
- ☐ Open PowerShell in that folder (click the File Explorer address bar, type `powershell`, press Enter) and run `sf config set target-org lumenfield`. Then `sf org display` should show your org. The setting is saved in `.sf\`, which Git ignores
- ☐ GitHub Desktop → **File** → **Add local repository** → **Choose…** → `C:\Lumenfield-steward` → **Add repository**. It will say the folder isn't a Git repository yet: click **create a repository**, leave the name as it is, leave Git ignore and License as **None** (the repo already has a `.gitignore`), then **Create repository**
- ☐ If anything shows under **Changes**, commit it with the summary `v0.1 — Phase 1: requirements, decisions, conventions`
- ☐ **Publish repository** → set **Name** to `lumenfield-steward` (lowercase, to match `lumenfield-accord`) → untick **Keep this code private** → **Publish repository**
- ☐ Tag the phase: **History** tab → right-click the latest commit → **Create Tag…** → `v0.1` → **Create Tag**, then **Push origin**

**Decisions for you** (the defaults stand if nothing changes before Phase 3)
- ☐ `Self_Service_Broken_Promise_Limit` = **2**: customers with 2 or more broken promises in 90 days are handed to a person instead of arranging online (ST-04)
- ☐ `Self_Service_Min_Coverage_Pct` = **100**: online arrangements must cover the full past-due balance; partial arrangements go to a person (ST-04)
- ☐ `Production_Guarantee_Pct` = **90**: a system that produces under 90% of its estimate over 12 months gets a credit review (ST-14)

---

## Found in the org — 2026-10-16

- Omni-Channel is on: `sfdc_livemessage` and `sfdc_phone` service channels exist
- Messaging is available, with no channels yet
- No agents exist yet. The admin has the Einstein Agent Platform permission, and the new Agentforce Builder (Agent Script) is available
- The Trust Layer's master **Prompt Security** setting reads off (ST-17, decided in Phase 6)
- The **Turn on Einstein** switch couldn't be read through the API (Phase 2 checks it by hand)
- Digital Experiences is off (turned on in Phase 4). Dev Hub is off and stays off (S-05)
- Active users: Zana Yocum and OrgFarm EPIC (System Administrator), Test Persona (Minimum Access). Four Salesforce licenses, three in use
- Customer licenses can't be given opportunity access, so commitments reach customers through a scoped read service (S-08). Accord's DEF-07 field `Commitment__c.Account__c` is what makes the household filter simple

---

## To check in the phase that needs it

**Phase 2 — Setup**
- ☐ Setup → Einstein Setup → confirm **Turn on Einstein** is on
- ☐ GitHub: confirm push protection is on, and protect `main` so pull requests need passing checks
- ☐ Certificate and External Client App `Steward_CI` so the pipeline can sign in (S-05). The private key goes in GitHub encrypted secrets, never in the repo

**Phase 3 — Apex services**
- ☐ Create the three new policy settings with the values decided above
- ☐ Find a household whose statements show an escalator step, for ST-03's known-answer test. If the dataset has none, add two statements to one test household

**Phase 4 — Portal**
- ☐ Setup → Digital Experiences → Settings → **Enable Digital Experiences**
- ☐ Account owners must have a role before a contact can become a customer user. The admin holds the Collections Supervisor role, so households the admin owns should already qualify; confirm on the test households
- ☐ Review the text of the 31 commitments' `Terms__c` before customers can see it (ST-02). It was written by sales reps for internal readers. If any is unsuitable, add a customer-facing summary field instead
- ☐ Confirm in the org that customer licenses can't be given opportunity access (S-08) and that Enhanced Chat works in an LWR site (S-11)

**Phase 6 — Service agent**
- ☐ Confirm how the logged-in customer's identity reaches the agent (S-07)
- ☐ Confirm whether the chat transcript can mask a typed card number (ST-05)
- ☐ Decide the Trust Layer settings and record them in `docs/agent-governance.md` (ST-17)

**Phase 7 — Payments**
- ☐ Create a free Stripe account and keep it in test mode. The test secret key goes into the `Stripe_Test` External Credential, nowhere else

---

## Risks to watch

- **Einstein usage is capped in Developer Edition**, and agent test runs use it. Keep test suites focused and run the full set at release.
- **Data 360 usage is capped** too, which is why ST-14 is a Should.
- **Five customer licenses.** The plan uses three test households, which leaves room for a fourth if a test needs one.
- **Accord's DEF-07 is unfinished** (the Commitments related list isn't on the account layout). That's tracked in Accord's open items. Steward depends only on the `Account__c` field, which is done.
