# Open Items — Steward

Everything deferred, flagged or half-finished. Updated at the end of every sitting. Nothing gets to live only in a chat log or someone's memory.

**Status key:** ☐ open · ☑ done · ⊘ deliberately not doing

---

## Phase 2 — Setup — started 2026-10-16

Built: `validate.yml` and `deploy.yml` (checked with actionlint), `docs/pipeline.md`, decisions S-12 and S-13, and the first change to send through the pipeline: the three new policy settings. Code Analyzer was dry-run on `force-app/` before delivery: 0 violations.

**Your steps** (full detail in `docs/pipeline.md` → Setup)
- ☐ A. Setup → Einstein Setup → **Turn on Einstein** on
- ☐ B. Key and certificate made in `C:\Lumenfield-keys`, outside the repo
- ☐ C. Permission set `PS_Steward_CI`, user Steward CI (System Administrator), permission set assigned
- ☐ D. External client app Steward CI: JWT, certificate, pre-authorized through `PS_Steward_CI`; consumer key copied
- ☐ E. `sf org login jwt` works from your computer
- ☐ F. Four GitHub secrets added; push protection on
- ☐ G. Branch `feature/ST-13-pipeline`, Phase 2 zip extracted, pull request opened, `validate` green
- ☐ H. `Protect main` ruleset created, pull request merged, `Deploy` green
- ☐ Delete `C:\Lumenfield-keys\steward-ci.key` once the deploy is confirmed in the org

**Mine, after your merge**
- ☐ Confirm the three policy settings exist in the org with the right values, then close Phase 2 in the CHANGELOG
- ☐ Confirm the `v0.1` tag reached GitHub. It wasn't there on 2026-10-16; GitHub Desktop sends tags with the next push, so it should go up with the Phase 2 branch

**Decisions for you** (the defaults go into the org with the first pull request, so say so before committing if you want different values)
- ☐ `Self_Service_Broken_Promise_Limit` = **2**: customers with 2 or more broken promises in 90 days are handed to a person instead of arranging online (ST-04)
- ☐ `Self_Service_Min_Coverage_Pct` = **100**: online arrangements must cover the full past-due balance; partial arrangements go to a person (ST-04)
- ☐ `Production_Guarantee_Pct` = **90**: a system that produces under 90% of its estimate over 12 months gets a credit review (ST-14)

---

## Phase 1 — Requirements — 2026-10-16

- ☑ Org facts read for the stories: policy settings, dispute evidence (16 records), statuses and types, record types, fields on the five Accord objects, Case, Account and Service Contract
- ☑ `docs/requirements.md` (18 stories), `docs/decision-log.md`, `docs/conventions.md`, `docs/brief.md`
- ☑ Phase 2 readiness checked (see Found in the org)
- ☑ `C:\Lumenfield-steward` created, default org set to `lumenfield`, repo published as `lumenfield-steward`
- ☑ Repo made public (confirmed 2026-10-16: public, default branch `main`)

---

## Found in the org — 2026-10-16

- Omni-Channel is on: `sfdc_livemessage` and `sfdc_phone` service channels exist
- Messaging is available, with no channels yet
- No agents exist yet. The admin has the Einstein Agent Platform permission, and the new Agentforce Builder (Agent Script) is available
- The Trust Layer's master **Prompt Security** setting reads off (ST-17, decided in Phase 6)
- The **Turn on Einstein** switch couldn't be read through the API (Part A checks it by hand)
- Digital Experiences is off (turned on in Phase 4). Dev Hub is off and stays off (S-05)
- Active users: Zana Yocum and OrgFarm EPIC (System Administrator), Test Persona (Minimum Access). Four Salesforce licenses, three in use; Steward CI takes the fourth (S-12)
- Customer licenses can't be given opportunity access, so commitments reach customers through a scoped read service (S-08). Accord's DEF-07 field `Commitment__c.Account__c` is what makes the household filter simple

---

## To check in the phase that needs it

**Phase 3 — Apex services**
- ☐ Add the 90% per-class coverage check to `validate.yml` with the first Apex class (ST-13)
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
- ☐ Add agent publish and activate to `deploy.yml` (S-10)

**Phase 7 — Payments**
- ☐ Create a free Stripe account and keep it in test mode. The test secret key goes into the `Stripe_Test` External Credential, nowhere else

---

## Risks to watch

- **Einstein usage is capped in Developer Edition**, and agent test runs use it. Keep test suites focused and run the full set at release.
- **Data 360 usage is capped** too, which is why ST-14 is a Should.
- **Five customer licenses.** The plan uses three test households, which leaves room for a fourth if a test needs one.
- **No spare Salesforce licenses** after Steward CI. A second persona user would mean switching Test Persona between roles, as Accord did.
- **Quick deploy with no Apex in the org yet.** If Salesforce won't quick-deploy a validation that ran no tests, `deploy.yml` deploys again with tests and says so in the log. Expected to go away once Phase 3 adds Apex tests.
- **Accord's DEF-07 is unfinished** (the Commitments related list isn't on the account layout). That's tracked in Accord's open items. Steward depends only on the `Account__c` field, which is done.
