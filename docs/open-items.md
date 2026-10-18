# Open Items — Steward

Everything deferred, flagged or half-finished. Updated at the end of every sitting. Nothing gets to live only in a chat log or someone's memory.

**Status key:** ☐ open · ☑ done · ⊘ deliberately not doing

---

## Phase 2 — Pipeline — closed 2026-10-17

The first change went through the whole pipeline: pull request #1 validated as Steward CI, merged, deployed as Steward CI, and the three new policy settings confirmed in the org (details in `CHANGELOG.md` v0.2).

- ☑ A–H from `docs/pipeline.md` → Setup: Steward CI user and permission set, external client app with JWT, sign-in tested locally, four GitHub secrets, `Protect main` ruleset, pull request #1 merged
- ☑ `Self_Service_Broken_Promise_Limit` = 2, `Self_Service_Min_Coverage_Pct` = 100, `Production_Guarantee_Pct` = 90 in the org (defaults accepted)
- ⊘ Repository-level push protection: the setting didn't appear for this personal public repo; account-level push protection is on by default for public repositories

**Your steps to close it** (about 5 minutes)
- ☐ GitHub Desktop → **Current Branch** → **main** → **Fetch origin** → **Pull origin**
- ☐ On pull request #1, click **Delete branch**. The feature branch is merged and done
- ☐ Extract `steward-phase2-close.zip` into `C:\Lumenfield-steward` (replace files), commit to `main` as `Phase 2 closed: pipeline verified in the org`, then **Push origin**. It's docs only, so no deploy runs, and the ruleset lets you push docs straight to `main`
- ☐ Replace the stray `Push-orgin` tag with `v0.1` and `v0.2`, in PowerShell from `C:\Lumenfield-steward`:
  ```powershell
  git pull
  git push origin --delete Push-orgin
  git tag -d Push-orgin
  git tag v0.1 d4afaa0
  git tag v0.2
  git push origin v0.1 v0.2
  ```
- ☐ Delete the private key: `Remove-Item C:\Lumenfield-keys\steward-ci.key`. GitHub holds the copy the pipeline needs
- ☐ Setup → Einstein Setup → confirm **Turn on Einstein** is on (Part A; needed by Phase 5)

**Mine, next sitting**
- ☐ Note which path the first deploy took (quick deploy or the fallback). The org records both runs the same way, so the Deploy run log is the source

---

## Phase 1 — Requirements — 2026-10-16

- ☑ Org facts read for the stories: policy settings, dispute evidence (16 records), statuses and types, record types, fields on the five Accord objects, Case, Account and Service Contract
- ☑ `docs/requirements.md` (18 stories), `docs/decision-log.md`, `docs/conventions.md`, `docs/brief.md`
- ☑ `C:\Lumenfield-steward` created, default org set to `lumenfield`, repo published as `lumenfield-steward` and made public

---

## Found in the org — 2026-10-16

- Omni-Channel is on: `sfdc_livemessage` and `sfdc_phone` service channels exist
- Messaging is available, with no channels yet
- No agents exist yet. The admin has the Einstein Agent Platform permission, and the new Agentforce Builder (Agent Script) is available
- The Trust Layer's master **Prompt Security** setting reads off (ST-17, decided in Phase 6)
- The **Turn on Einstein** switch couldn't be read through the API (checked by hand, above)
- Digital Experiences is off (turned on in Phase 4). Dev Hub is off and stays off (S-05)
- Salesforce licenses: all four in use (Zana Yocum, OrgFarm EPIC, Test Persona, Steward CI)
- Customer licenses can't be given opportunity access, so commitments reach customers through a scoped read service (S-08). Accord's DEF-07 field `Commitment__c.Account__c` is what makes the household filter simple

---

## To check in the phase that needs it

**Phase 3 — Apex services (next)**
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
- **No spare Salesforce licenses** now that Steward CI has the fourth. A second persona user would mean switching Test Persona between roles, as Accord did.
- **Accord's DEF-07 is unfinished** (the Commitments related list isn't on the account layout). That's tracked in Accord's open items. Steward depends only on the `Account__c` field, which is done.
