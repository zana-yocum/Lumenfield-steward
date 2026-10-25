# Open Items — Steward

Everything deferred, flagged or half-finished. Updated at the end of every sitting. Nothing gets to live only in a chat log or someone's memory.

**Status key:** ☐ open · ☑ done · ⊘ deliberately not doing

---

## Phase 5 — Rep assistant — in progress

Pull request #9 built it: the three prompt templates and the Apex behind them, the three buttons, and the permission sets. #10 activated the templates and added the docs. #11 fixed what the org checks found and recorded their evidence. #13 records what the hand check found and finishes Accord's DEF-07 on the account layout. Claude pushes each one, merges it once its final commit validates, and checks the deploy.

**Your steps**
- ☑ 1. Three decisions (2026-10-23): specialists and supervisors read a case's subject, description, account and contact; reps, specialists and supervisors read contact email and phone numbers; a follow-up is drafted for every outcome (S-21, S-22)
- ☐ 2. Hand check as Test Persona (steps below). **Steps 1–4 done 2026-10-24** (login as Test Persona at 8:10 PM CT, in the audit trail). Step 5 stopped: Log Contact Attempt wasn't there. That was Accord's DEF-08, fixed the same night (below). **Steps 5–8 to finish**
- ☑ 3. Accord's changelog: the entry below is in Accord's `CHANGELOG.md` v1.0.2 (2026-10-24), on Accord's branch `release/v1.0.2`. It reaches Accord's `main` after your decision on Accord's history (Accord's open items, step 1)
- ☐ 4. `v0.5` tag once Phase 5 closes, from `C:\Lumenfield-steward` in PowerShell: `git tag v0.5 <commit>`, then `git push https://Zana-yocum@github.com/zana-yocum/Lumenfield-steward.git v0.5`. Claude gives you the commit
- ☐ 5. **Your private email is in this repository's history:** 19 commits on `main` carry it, the 12 pull-request merges and 7 commits pushed from your computer, because GitHub and your local git stamp commits with your account's primary address. Two steps stop new ones:
  - GitHub → your photo → **Settings** → **Emails** → tick **Keep my email addresses private** and **Block command line pushes that expose my email**.
  - In PowerShell, once: `git config --global user.email "<the noreply address shown on that page>"`.

  Until then, Claude merges pull requests by rebase, so no commit is made under your name. Removing the existing ones means rewriting `main` and recreating the v0.1–v0.4 tags: your decision
- ☐ 6. Optional cleanup on GitHub (**Branches**): `tools/accord-restore`, `retrieve/5` and `retrieve/6` were only used to restore Accord's repository and can be deleted. Claude can't delete branches

**Mine**
- ☑ Accord's components retrieved as they were, before any change (`retrieve/2`, `manifest/rep-assistant.xml`): the two layouts, the three collections groups and the Einstein settings (S-15)
- ☑ Einstein Prompt Templates license assigned to Test Persona (2026-10-23). Test Persona is the only member of the three groups, and the groups now include a permission set that needs the license (S-22)
- ☑ Built and checked before the pull request: 3 templates, 11 Apex classes and 8 test classes, 5 components with 20 Jest tests, 3 quick actions, 3 permission sets, 17 labels. Code Analyzer: 0 violations. Prettier and the personal-details check clean
- ☑ Docs: decisions S-20 to S-22, `docs/agent-governance.md`, 19 explainers, conventions and traceability
- ☑ Pull request #9 merged (10:58 AM CT) and quick-deployed as Steward CI (`0Afaj00000osZjyCAE`). In the org: the permission sets in the three groups, which recalculated, and the three templates, published
- ☑ The templates arrived inactive, so they can't generate yet. Retrieved (`retrieve/3`) with the identifiers the org generated
- ☑ Pull request #10: each template's active version named in source, and the docs. Validated (`0Afaj00000ovJCQCA2`, 159 of 159 tests), merged and quick-deployed (`0Afaj00000ouMkICAU`); the templates generate
- ☑ Org checks (2026-10-23), with the evidence in `docs/agent-governance.md`:
  - ☑ Known answers: briefings for Sandra Barnett, Tanya Lattimore and Angela Coffey; every figure matched the records
  - ☑ No history: Angela Prather's briefing is one sentence saying there's nothing to discuss
  - ☑ Adversarial: COM-00034's terms and dispute 00001054's description, both on Andre Radcliff's household, were reported as content and not followed; nothing was recommended
  - ☑ Follow-up: a Promise Made draft with the promise's amount and date from PTP-00142, and no promotional content
  - ☐ Payment method in a rep's briefing: none expected, since Test Persona can't read it (below). Confirmed in your hand check
- ☑ Found by the checks: 00001035's summary called an unflagged commitment a possible match. Pull request #11 marks every other commitment as not flagged: validated (`0Afaj00000ovn8rCAA`, 159 of 159 tests), merged and deployed (`0Afaj00000ovl74CAA`). Rerun: the commitment is now described as not flagged
- ☑ Test records removed: COM-00034 deleted; dispute 00001054 closed, and Accord set STMT-00640 back to Past Due. The Promise Made attempt and PTP-00142 stay on Andre Radcliff's household as ordinary activity; the attempt's notes say it was an org check
  - ☑ Persona access (2026-10-23): Test Persona can read every field the templates read except the payment method, the processor reference, and a case's description, subject, account and contact, as S-22 intends
- ☑ **Hand check finding, 2026-10-24: Accord's DEF-08.** Test Persona saw Briefing and Follow-up Draft but not Log Contact Attempt. The action launches Accord's screen flow `Account_Screen_LogContactAttempt`, and a user needs the Run Flows permission or access to that flow. Minimum Access and Accord's permission sets gave neither. Fixed in the org the same night, least privilege, in Accord's components: flow version 3 restricts access to enabled permission sets, and `PS_Collections_Core` grants that one flow. Checked through the API: the three collections groups recalculated with the access; Sales Rep has none. Recorded in Accord's CHANGELOG v1.0.2 and results doc. Steward's Follow-up Draft needs a logged attempt, so it had been unusable for real reps
- ☑ Pull request #13: the three collections groups' descriptions corrected. They still described a muted Promise to Pay delete that Accord's OBS-01 removed. Also in #13: the Commitments related list on the Residential Agreement layout, which finishes Accord's DEF-07, and the Phase 4 portal screenshots in `docs/screenshots/phase-4/`, moved from Accord's repository
- ☑ Accord's repository restored, using this repository's retrieve workflow. Accord's `main` had lost its custom objects, fields, permission sets, groups and analytics in its Phase 6 commit. The workflow ran from the branch `tools/accord-restore` (runs 5 and 6); the second run's version of the workflow swapped org usernames for `example.com` placeholders before the personal-details check. Never merged here. Retrieving them also showed no drift in the components this repository owns: the two layouts differ from the org only by empty columns, and the three groups match exactly

**Hand check (step 2), about 10 minutes, after Claude says the templates are active**
1. In Salesforce as yourself: the gear icon → **Setup** → type `Users` in Quick Find → **Users** → click **Login** next to **Test Persona**.
2. App Launcher (the nine dots) → **Collections Console** → search for **Sandra Barnett Household** and open it.
3. Click **Briefing** at the top right of the record (if you don't see it, it's under the ▼ arrow). The panel says "Writing from this record…", then shows the briefing. Check: the balance, past-due balance and days past due match the fields on the record; no payment method appears anywhere (a rep can't read it); Disputes names 00001035 and says its milestone was missed; the reminder to check it sits at the bottom. Click **Close**.
4. Click **Follow-up Draft**. It should say: "Log today's contact attempt first, so the draft reflects what happened on the call." Click **Close**.
5. Click **Log Contact Attempt** (refresh the page first; it was missing until DEF-08 was fixed on 2026-10-24), choose **Left Voicemail**, type a short note such as `Hand check`, and finish.
6. Click **Follow-up Draft** again. The email composer opens with the subject "We tried to reach you today", a body starting "Hi Sandra," and the sign-off "Thank you," with Test Persona and Lumenfield Home Energy. The To line should hold Sandra's address (an example.com address). **Don't send it:** close the composer and choose **Discard**.
7. In the household's cases, open **00001035** and click **Dispute Summary**. As a rep, "What the customer said" should say the description isn't available to you; the evidence for Outage or Repair Credit and the missed milestone should be there. Click **Close**.
8. Top right: **Log out as Test Persona**. Then tell Claude "hand check done", with anything that looked wrong.

**Accord's changelog entry (step 3), ready to paste**
```
### Changed by Steward (2026-10-23)
- Residential Agreement account layout: Steward's Briefing and Follow-up Draft actions and the
  standard Email action added to the Lightning actions, which now read Briefing, Log Contact
  Attempt, Follow-up Draft, Email, Edit.
- Billing Dispute case layout: Steward's Dispute Summary action added first to the Lightning actions.
- Collections Rep, Dispute Specialist and Collections Supervisor permission set groups: Steward's
  PS_Steward_Rep_Assistant and PS_Steward_Collections_Contact added to all three, and
  PS_Steward_Dispute_Specialist to the specialist and supervisor groups (Steward S-22). Accord's
  own permission sets are unchanged.
- Found: no persona could read a case's Subject, Description, AccountId or ContactId, and reps
  couldn't read a contact's Email, Phone or MobilePhone or the account's Phone. Steward closes
  this for the collections personas (S-22).
- Found: Collection_Hold_Until__c's description is a copy of Do_Not_Contact__c's (fixed in
  Accord v1.0.2).
```

**Pull request #9's validations**
- ☑ First (`0Afaj00000ortiQCAQ`): 13 component errors, one cause. Salesforce has retired the flex capability type (`FlexTemplate://…`), so the three data classes didn't compile and everything depending on them failed. Removed (S-20)
- ☑ Second (`0Afaj00000osgezCAA`): the Apex compiled; three errors, the templates' made-up version identifiers. The org generates them, so they're left out of a new template's source
- ☑ Third (`0Afaj00000os6mpCAA`): 259 components, 159 of 159 tests, every class at 90% or more

## Phase 4 — Customer portal — closed 2026-10-22

Three pull requests. #4 turned on Digital Experiences and added the retrieve workflow (S-15). #5 built the site's pages, the controllers, the sharing and `PS_Steward_Customer`, with their tests. #6 switched off the customer profiles' default access and repaired the disputes from before the household flow. Claude pushes the branches, opens the pull requests and merges them once their final commit validates.

**Your steps**
- ☑ 1. Yes to turning on Digital Experiences, which Salesforce can't turn off again (2026-10-18, 12:00 PM CT)
- ☑ 2. Placeholder email sender for the site, `portal@lumenfield.example` (option b, 2026-10-18)
- ☑ 3. Branch `retrieve/1` deleted on GitHub (2026-10-22): it held your private email and Salesforce username
- ☑ 4. Walkthrough and screenshots as Sandra Barnett, Tanya Lattimore and Angela Coffey, with the privacy check (2026-10-22, by 7:48 PM CT). The contact page had no **Log in to Experience as User** (see below), so each login used the admin's login-as link for the site
- ☑ 5. `v0.4` tagged on `9634423` and pushed (2026-10-22)

**Mine**
- ☑ 4a through the pipeline: Digital Experiences on, `retrieve.yml` (pull request #4, merged)
- ☑ Site created from the Build Your Own (LWR) template and retrieved into the repo, with placeholders where the org had put personal details
- ☑ Personal-details check in `retrieve.yml` and `validate.yml`, with tests
- ☑ 4b, pull request #5: pages, controllers, sharing, profiles, labels and tests. Fifth validation passed; merged 8:27 PM CT 2026-10-21, quick-deployed as Steward CI, and the portal published by the pipeline (details in `CHANGELOG.md` v0.4)
- ☑ Site Live and published; the components, flows and profiles in the org, last changed by Steward CI
- ☑ Customer users for Sandra Barnett (behind on payments, with a dispute), Tanya Lattimore (current, with a dispute) and Angela Coffey (nothing on record), each on Steward Customer with `PS_Steward_Customer` (`scripts/apex/create-demo-customers.apex`, 2026-10-21)
- ☑ Pull request #6: the custom profiles carried their license's 25 default objects; each is now switched off, and `PS_Steward_Customer` grants read on contacts, which the dispute needs. The household flow repairs a dispute on any save. Second validation passed (115 of 115); deployed 8:50 PM CT
- ☑ Backfill run: all 14 billing disputes saved. Checked through access: each demo customer can read only their own dispute, and none can see a default review
- ☑ S-04, S-08 and S-11 confirmed, and S-14's field-level refusal tested with a customer user
- ☑ `CHANGELOG.md` v0.4 finished, with #6's deploy and the backfill (pull request #7)

**Pull request #5's validations**
- ☑ First (`0Afaj00000oE785CAC`): two components refused. The household flow cleared its lookup with `$GlobalConstant.EmptyString`, and the sharing set's description was over 255 characters
- ☑ Second (`0Afaj00000oE7PpCAK`): every component accepted; 14 of 99 tests failed. The org won't create users on the standard external profiles (S-18), and four tests looked up statements by a status Accord changes when a dispute opens
- ☑ Third (`0Afaj00000oE8FRCA0`): 202 components accepted; 5 of 108 tests failed. Customer licenses can't use service contracts, so every dispute a customer opened failed (S-19), and a file an external user uploads needs the site's network
- ☑ Fourth (`0Afaj00000odYOQCA2`, 2026-10-21): 203 components accepted; 112 of 113 tests passed, every new class at 100%. The one failure read the new case's owner by name and got nothing back; it now compares the queue's ID, as the Phase 3 test does
- ☑ Fifth (`0Afaj00000odfg1CAA`): 114 of 114 tests, 203 components, every class at 90% or more

**Checked in the org after the walkthrough (2026-10-22)**
- ☑ Angela Coffey opened dispute 00001053 in the portal, 7:44 PM CT: created by her customer user, origin Web, reason Payment Not Posted. The agreement flow stamped Coffey Household Lease (S-19); Accord stamped the Billing Dispute SLA entitlement, routed the case to Dispute Specialists and set statement STMT-00854 to In Dispute (ST-06)
- ☑ Angela can read 00001053 but not edit it, and still can't read Sandra Barnett's dispute (S-16, ST-12)

**For a later phase**
- ☑ Upload a file to a dispute as a customer, by hand: done 2026-10-23, 8:32 AM CT. Angela Coffey's customer user attached a PNG to 00001053 through the portal (checked in the org, 2026-10-24)
- ☐ Phase 10, before the walkthrough video: decide whether to add **Log in to Experience as User** to the Contact page layout. The layout has its own customized list of Lightning actions, so the customer-user actions Salesforce adds don't appear on it. The layout is Accord's, so adding the action is an Accord change with its own changelog entry (NFR-09); the alternative is to keep using the admin's login-as link

**Known and accepted**
- ⊘ Graph Engine's two findings are the S-08 commitments read, by design (`docs/pipeline.md`)
- ⊘ The portal's evidence upload is proven in Apex (a customer can attach a file to their own dispute, not another household's), and the control itself by hand (above)

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
- ☑ 8c. Tags pushed with your `Zana-yocum` account, 11:45 AM CT: `v0.1` on `d4afaa0`, `v0.2` on `a32a79a` and `v0.3` on `6790b1f`. The stray `Push-orgin` tag is deleted. The first try was refused because the command line signs in to GitHub as a different account; naming `Zana-yocum@` in the address fixed it. Tags stay with you, so each phase ends with two lines in PowerShell from `C:\Lumenfield-steward`: `git tag v0.4 <commit>`, then `git push https://Zana-yocum@github.com/zana-yocum/Lumenfield-steward.git v0.4`
- ☑ 9. Private key deleted from `C:\Lumenfield-keys` (11:47 AM CT, by you). The only copy left is the `SF_PRIVATE_KEY` GitHub secret the pipeline uses
- ☑ 10. **Turn on Einstein** confirmed on in Einstein Setup (11:47 AM CT, checked by hand: the switch can't be read through the API). Phase 5 needs it

**Known and accepted**
- ⊘ No retrieve manifest for Phase 3: everything was built in source, nothing in Setup
- ☑ Graph Engine data-flow rules: they start from entry points, and the portal's controllers are the first. Run in Phase 4: two findings, both the S-08 read by design (`docs/pipeline.md`). Run again when the Phase 6 actions exist
- ⊘ 22 of 864 lines no test reaches yet. Seven are `PaymentArrangementService`'s safety net, which Accord's current rules can't trigger. Thirteen are in `DisputeIntakeService`: a caller who can create cases but not one of the dispute fields, a rejected save, and an over-long description. The field-level refusal is now tested in Phase 4 with a customer user (S-14)

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
- → Turning on Digital Experiences moved into the pipeline: Phase 4a, approved 2026-10-18
- ☑ Account owners must have a role before a contact can become a customer user. All 88 households are owned by the admin, who holds the Collections Supervisor role (read 2026-10-18)
- ☑ The 31 commitments' `Terms__c` reviewed (ST-02, 2026-10-18). Each is one of four plain sentences in the rep's voice. Nothing internal or unsuitable, so the portal shows them as recorded and no customer-facing field is needed
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

- **Steward's source is now the copy of record for two Accord layouts and three Accord groups** (S-21, S-22). A change made to them in Setup is undone by Steward's next deploy unless it's retrieved into Steward first (S-15). That includes Accord's unfinished DEF-07, the Commitments related list on the Residential Agreement layout, which now has to be added in Steward's source.
- **Einstein usage is capped in Developer Edition**, and agent test runs use it. Keep test suites focused and run the full set at release.
- **Data 360 usage is capped** too, which is why ST-14 is a Should.
- **Five customer licenses.** The plan uses three test households, which leaves room for a fourth if a test needs one.
- **No spare Salesforce licenses** now that Steward CI has the fourth. A second persona user would mean switching Test Persona between roles, as Accord did. Apex tests use a Salesforce Platform user instead.
- **Apex test time.** Every pull request now runs 83 tests in the org, and five of them build 200 households through Accord's flows. Phase 3's three runs took 227, 114 and 149 seconds of test time. In the third, the slowest test, opening 200 disputes, took 32 seconds. If a run nears the CPU limit, the bulk tests are where to look.
- **Nobody can read the action log's fields yet**, the admin included, until `PS_Steward_Supervisor` in Phase 6. Records are written and counted, but anyone opening one would see only its number and outcome. Expected for now.
- ☑ **Accord's DEF-07 finished by pull request #13:** the Commitments related list is on the Residential Agreement layout, which this repository maintains. Steward depends only on the `Account__c` field.
