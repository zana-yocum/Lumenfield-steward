# Open Items — Steward

Everything deferred, flagged or half-finished. Updated at the end of every sitting. Nothing gets to live only in a chat log or someone's memory.

**Status key:** ☐ open · ☑ done · ⊘ deliberately not doing

---

## Phase 3 — Apex services — closed 2026-10-18

Pull request #2 passed its third validation, merged, and the pipeline quick-deployed it as Steward CI. The 26 classes and the action log are in the org, all 83 tests passed, and every class is at 90% or more (details in `CHANGELOG.md` v0.3).

- ☑ Built and checked before delivery: 13 Apex classes, 12 test classes with 83 tests, `Agent_Action_Log__c`, the 90% per-class coverage gate, 14 explainers, and decision S-14
- ☑ First validation, 10:24 AM CT (`0Afaj00000oBq9lCAC`): 78 of 82 tests passed. Fixed: the log tests' read-backs, `PaymentArrangementService` at 87.1%, and a test that took two minutes
- ☑ Second validation, 10:51 (`0Afaj00000oBuQHCA0`): 82 of 83 passed. Fixed: the rejected-save test's amount fit the currency field
- ☑ Third validation, 11:03 (`0Afaj00000oBwtVCAS`): 83 of 83 passed, 36 of 36 components. The lowest class is `DisputeIntakeService` at 92.1%
- ☑ Merged, and deployed at 11:04 (`0Afaj00000oBxXpCAK`) by quick deploy: no tests, 7 seconds. That settles which path the deploy takes, carried from Phase 2
- ☑ Verified in the org: the 26 classes, Active at API 68.0, and `Agent_Action_Log__c` with its six fields, all last changed by Steward CI

**Your steps**
- ☑ 1–7. Branch, zip, commit, publish, pull request, two fixes, merge (2026-10-18)
- ☑ 8a. Close-out commit pushed from GitHub Desktop (`6790b1f`, 11:28 AM CT). Its files match what was prepared
- ☑ 8b. Claude connected to GitHub: account linked and the Claude GitHub App installed on `lumenfield-steward` (2026-10-18). Claude can push branches and open pull requests. It can't push or delete tags (refused, 403), so tags stay with you
- ☐ 8c. Tags. The first PowerShell push was refused because the command line signs in to GitHub as a different account, which can't write to this repo. Putting `Zana-yocum@` in the address makes it use yours: if a sign-in window opens, sign in as `Zana-yocum`. In PowerShell from `C:\Lumenfield-steward` (`-f` sets each tag even if an old one is still there):
  ```powershell
  git tag -f v0.1 d4afaa0
  git tag -f v0.2 a32a79a
  git tag -f v0.3 6790b1f
  git push https://Zana-yocum@github.com/Zana-yocum/lumenfield-steward.git v0.1 v0.2 v0.3
  git push https://Zana-yocum@github.com/Zana-yocum/lumenfield-steward.git --delete Push-orgin
  ```
- ☐ 9. If not done yet: delete the private key with `Remove-Item C:\Lumenfield-keys\steward-ci.key`. GitHub holds the copy the pipeline needs
- ☐ 10. If not done yet: Setup → Quick Find **Einstein Setup** → confirm **Turn on Einstein** is on (Phase 5 needs it)

**Known and accepted**
- ⊘ No retrieve manifest for Phase 3: everything was built in source, nothing in Setup
- ⊘ Graph Engine data-flow rules: they start from entry points (invocable and Aura-enabled methods), and Steward has none yet. Run them once the Phase 6 actions exist
- ⊘ 22 of 864 lines no test reaches yet. Seven are `PaymentArrangementService`'s safety net, which Accord's current rules can't trigger. Thirteen are in `DisputeIntakeService`: a caller who can create cases but not one of the dispute fields, a rejected save, and an over-long description. The field-level refusal is checked with the agent user in Phase 6 (below)

---

## Phase 2 — Pipeline — closed 2026-10-17

The first change went through the whole pipeline: pull request #1 validated as Steward CI, merged, deployed as Steward CI, and the three new policy settings confirmed in the org (details in `CHANGELOG.md` v0.2).

- ☑ A–H from `docs/pipeline.md` → Setup: Steward CI user and permission set, external client app with JWT, sign-in tested locally, four GitHub secrets, `Protect main` ruleset, pull request #1 merged
- ☑ `Self_Service_Broken_Promise_Limit` = 2, `Self_Service_Min_Coverage_Pct` = 100, `Production_Guarantee_Pct` = 90 in the org (defaults accepted)
- ☑ Phase 2 close-out committed to `main` (`a32a79a`), feature branch deleted
- ⊘ Repository-level push protection: the setting didn't appear for this personal public repo; account-level push protection is on by default for public repositories
- → Tags, deleting the key file and the Einstein check moved to Phase 3, steps 8 to 10
- → Which path the first deploy took moved to Phase 3

---

## Phase 1 — Requirements — 2026-10-16

- ☑ Org facts read for the stories: policy settings, dispute evidence (16 records), statuses and types, record types, fields on the five Accord objects, Case, Account and Service Contract
- ☑ `docs/requirements.md` (18 stories), `docs/decision-log.md`, `docs/conventions.md`, `docs/brief.md`
- ☑ `C:\Lumenfield-steward` created, default org set to `lumenfield`, repo published as `lumenfield-steward` and made public

---

## Found in the org

**2026-10-18 (Phase 3)**
- `Case.AccountId` is read-only in all 42 profiles and permission sets that include it, System Administrator among them, though the field itself can be granted. That's why the dispute insert runs in system mode (S-14)
- The org has no Apex triggers and no workflow rules. Accord's automation is 9 record-triggered flows and 3 scheduled flows. The scheduled ones (account status, broken-promise count, promise evaluation) don't run during Apex tests, so tests set those fields themselves
- No household in Accord's data has an escalator step in its statements
- Salesforce Platform licenses: six, none used. The Standard Platform User profile can read and create accounts and contacts only, with no access to cases or Accord's objects, which makes it a clean "can't see anything" test user
- From the first validation: a plain query in an Apex test checks field-level security, so it can't read fields nobody has access to (S-09's new log fields). Read-backs now say `WITH SYSTEM_MODE`
- From the same run: `Security.stripInaccessible` let the pipeline user (System Administrator) create `Case.AccountId`, though the profile's field permission says read-only. Phase 6 checks the agent user (S-14)
- From the second validation: `Promise_Amount__c` is Currency(16, 2), which means 16 digits before the decimal point (precision 18 in the API). A 16-digit amount saved, so the rejected-save test uses 21
- From the merge: a quick deploy shows in the org's deployment history as a deployment that ran no tests and took seconds, with the same package as the validation it reused (`0Afaj00000oBxXpCAK`: 60 files, 7 seconds)

**2026-10-16 (Phase 1)**
- Omni-Channel is on: `sfdc_livemessage` and `sfdc_phone` service channels exist
- Messaging is available, with no channels yet
- No agents exist yet. The admin has the Einstein Agent Platform permission, and the new Agentforce Builder (Agent Script) is available
- The Trust Layer's master **Prompt Security** setting reads off (ST-17, decided in Phase 6)
- The **Turn on Einstein** switch couldn't be read through the API (checked by hand)
- Digital Experiences is off (turned on in Phase 4). Dev Hub is off and stays off (S-05)
- Salesforce licenses: all four in use (Zana Yocum, OrgFarm EPIC, Test Persona, Steward CI)
- Customer licenses can't be given opportunity access, so commitments reach customers through a scoped read service (S-08). Accord's DEF-07 field `Commitment__c.Account__c` is what makes the household filter simple

---

## To check in the phase that needs it

**Phase 3 — Apex services**
- ☑ The 90% per-class coverage check is in `validate.yml` (ST-13)
- ☑ Escalator known-answer data: the dataset has no escalator step, so `StatementExplanationServiceTest` builds its own household ($120.00, then $123.48 at the first anniversary)

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
- ☐ Invocable actions, one per service call (`<Verb><Noun>Action`): each takes the verified account from the session, calls the service, writes one log record through `AgentActionLogger`, and returns the typed result
- ☐ Decide what `Agent_Action_Log__c.Conversation_Id__c` holds (the messaging session's ID is the likely answer) and how a supervisor opens the conversation from it
- ☐ `PS_Steward_Agent`, from what the Phase 3 services read and write in user mode. This becomes `docs/security-model.md`:
  - **Account:** read `Account_Status__c`, `Broken_Promises_90d__c`, `Current_Balance__c`, `Past_Due_Balance__c`, `Oldest_Past_Due_Date__c`, `Primary_Contact__c`. Residential Agreement accounts reached through a criteria-based sharing rule (S-01)
  - **Billing Statement:** read the statement fields, including `Service_Contract__c`
  - **Service Contract:** read `Escalator_Rate__c`, `First_Due_Date__c`, `StartDate`
  - **Lease Payment:** read name, date and amount only. No method, no processor reference
  - **Adjustment:** read `Type__c`, `Amount__c`, `Posted_Date__c`, `Status__c`, `Billing_Statement__c`
  - **Promise to Pay:** read and create `Promise_Date__c`, `Promise_Amount__c`, `Status__c`; read `Grace_Ends__c`
  - **Case:** create, plus create on `Disputed_Statement__c`, `Service_Contract__c`, `Dispute_Reason__c`, Origin, Subject, Description and Contact. Without them `DisputeIntakeService` answers `ACCESS_DENIED`. Also read access to Billing Dispute cases through sharing, so the agent can read back the case number once the case is in the Dispute Specialists queue
  - **Nothing on** `Commitment__c`, `Opportunity` or `Agent_Action_Log__c`: the services handle those (S-08, S-09)
- ☐ S-14 with the agent user, two checks. First, what its create access to `Case.AccountId` really is: if it can set the field, the dispute insert moves to user mode and the exception goes. Second, a dispute from a user who can create cases but not one of the dispute fields comes back `ACCESS_DENIED` naming that field, with nothing saved. Phase 3 could only test a user with no Case access (no Salesforce license is free), and the third validation shows the field-level lines never ran
- ☐ `PS_Steward_Supervisor`: read on `Agent_Action_Log__c`, for the Steward Agent dashboard (ST-11). Reps get nothing on it
- ☐ When a service returns `HANDOFF`, the reason code goes into the handoff summary, so the rep knows which limit was hit (ST-07)
- ☐ Run Code Analyzer's Graph Engine rules once the actions exist
- ☐ Add two statements showing an escalator step to one demo household, so ST-03 can be shown on real data, not just in tests

**Phase 7 — Payments**
- ☐ Create a free Stripe account and keep it in test mode. The test secret key goes into the `Stripe_Test` External Credential, nowhere else

---

## Risks to watch

- **Einstein usage is capped in Developer Edition**, and agent test runs use it. Keep test suites focused and run the full set at release.
- **Data 360 usage is capped** too, which is why ST-14 is a Should.
- **Five customer licenses.** The plan uses three test households, which leaves room for a fourth if a test needs one.
- **No spare Salesforce licenses** now that Steward CI has the fourth. A second persona user would mean switching Test Persona between roles, as Accord did. Apex tests use a Salesforce Platform user instead.
- **Apex test time.** Every pull request now runs 83 tests in the org, and five of them build 200 households through Accord's flows. Phase 3's three runs took 227, 114 and 149 seconds of test time. In the third, the slowest test, opening 200 disputes, took 32 seconds. If a run nears the CPU limit, the bulk tests are where to look.
- **Nobody can read the action log's fields yet**, the admin included, until `PS_Steward_Supervisor` in Phase 6. Records are written and counted, but anyone opening one would see only its number and outcome. Expected for now.
- **Accord's DEF-07 is unfinished** (the Commitments related list isn't on the account layout). That's tracked in Accord's open items. Steward depends only on the `Account__c` field, which is done.
