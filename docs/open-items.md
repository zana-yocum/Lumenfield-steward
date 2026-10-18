# Open Items — Steward

Everything deferred, flagged or half-finished. Updated at the end of every sitting. Nothing gets to live only in a chat log or someone's memory.

**Status key:** ☐ open · ☑ done · ⊘ deliberately not doing

---

## Phase 3 — Apex services — built 2026-10-18, first validation fixed

Built and checked before delivery (`CHANGELOG.md` v0.3): 13 Apex classes, 12 test classes with 83 tests, `Agent_Action_Log__c`, the 90% per-class coverage gate, 14 explainers, and decision S-14.

**First validation**, 2026-10-18 10:24 (`0Afaj00000oBq9lCAC`): all 36 components deployed, and 78 of 82 tests passed. The 4 failures were all in `AgentActionLoggerTest`: field-level security on the new log fields stopped the tests' plain read-back queries. The run also measured `PaymentArrangementService` at 87.1%, which the coverage gate would have stopped. Both are fixed, and a test that took two minutes is fixed too (details in `CHANGELOG.md` v0.3).

**Your steps**
- ☑ 1–5. Branch, zip, commit, publish, pull request (2026-10-18)
- ☐ 6. Update the pull request with the fix. In GitHub Desktop, check **Current Branch** says `feature/phase-3-apex-services`. Extract `steward-phase3-fix1.zip` into `C:\Lumenfield-steward` and replace the files. Commit with the summary `ST-04 ST-11: fix the log tests' read-backs, test a rejected promise save`, then **Push origin**. The **validate** check starts again on its own and takes about 6 minutes
- ☐ 7. When it's green: **Merge pull request** → **Confirm merge** → **Delete branch**. On the **Actions** tab, wait for **Deploy** to go green
- ☐ 8. Tags, in PowerShell from `C:\Lumenfield-steward`. This replaces the stray `Push-orgin` tag and tags all three phases. If a delete line says the tag doesn't exist, that's fine; carry on:
  ```powershell
  git checkout main
  git pull
  git push origin --delete Push-orgin
  git tag -d Push-orgin
  git tag v0.1 d4afaa0
  git tag v0.2 a32a79a
  git tag v0.3
  git push origin v0.1 v0.2 v0.3
  ```
- ☐ 9. If not done yet: delete the private key with `Remove-Item C:\Lumenfield-keys\steward-ci.key`. GitHub holds the copy the pipeline needs
- ☐ 10. If not done yet: Setup → Quick Find **Einstein Setup** → confirm **Turn on Einstein** is on (Phase 5 needs it)

**Mine**
- ☐ Read the second validation's results from the org: every test passing, and every class at 90% or more
- ☐ After the merge, verify in the org: the 26 classes and the log object exist, and the deployment ran as Steward CI. Record it in `CHANGELOG.md` v0.3 and close this section
- ☐ Note which path the deploy took. Phase 3 settles it: a quick deploy runs no tests, the fallback runs all 83 again. (Carried from Phase 2, where both paths looked the same because there was no Apex.)

**Known and accepted**
- ⊘ No retrieve manifest for Phase 3: everything was built in source, nothing in Setup
- ⊘ Graph Engine data-flow rules: they start from entry points (invocable and Aura-enabled methods), and Steward has none yet. Run them once the Phase 6 actions exist

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
- ☐ Carry the Phase 3 verification evidence into the repo with the Phase 4 pull request, if it hasn't gone in already

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
- **Apex test time.** Every pull request now runs 83 tests in the org, and five of them build 200 households through Accord's flows. The first run's tests took about 4 minutes, and the slowest bulk test 21 seconds. If a run nears the CPU limit, the bulk tests are where to look.
- **Nobody can read the action log's fields yet**, the admin included, until `PS_Steward_Supervisor` in Phase 6. Records are written and counted, but anyone opening one would see only its number and outcome. Expected for now.
- **Accord's DEF-07 is unfinished** (the Commitments related list isn't on the account layout). That's tracked in Accord's open items. Steward depends only on the `Account__c` field, which is done.
