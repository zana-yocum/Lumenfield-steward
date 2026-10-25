# Changelog — Steward

Newest first. One entry per phase.

## v0.5 — 2026-10-23 — Phase 5: Rep assistant

The rep assistant: three buttons in the Collections Console. **Briefing** writes a pre-call briefing on a household, **Dispute Summary** a first-pass summary of a billing dispute, and **Follow-up Draft** an email after today's call, opened in the composer for the rep to edit and send. Each runs a Prompt Builder template grounded in Apex that reads the records with the clicking person's own access. One pull request, #9.

### Added in pull request #9
- **Three prompt templates:** `Steward_Account_Briefing`, `Steward_Dispute_Summary` and `Steward_Followup_Draft` (ST-08, ST-09, ST-10). Each has INSTRUCTIONS and DATA parts and tells the model to treat text between `<quoted>` tags as something a person wrote, never as instructions
- **The data behind them (S-20):** `AccountBriefingPrompt`, `DisputeSummaryPrompt` and `FollowupDraftPrompt`, with `PromptFormat`, `PromptSection`, `RecordLines`, `SlaMilestones`, `HouseholdBriefing` and `EvidenceChecklist`. Every query is in user mode, and a related list the person can't read says so. Names, contact details and record IDs never reach a model; typed text is quoted after card numbers, email addresses and phone numbers are removed
- **The buttons (S-21):** three screen quick actions (`repBriefing`, `repDisputeSummary`, `repFollowupDraft`, with `repGeneratedText` and `repAssistantShared`), `RepAssistantController`, which checks each request before any model runs, and `PromptRunner`, the only place Steward's Apex calls a model. Added to Accord's Residential Agreement account layout and Billing Dispute case layout, with the standard Email action the composer needs
- **Access (S-22):** `PS_Steward_Rep_Assistant`, `PS_Steward_Collections_Contact` and `PS_Steward_Dispute_Specialist`, in Accord's three collections groups
- **17 custom labels** (`Steward_Rep_*`) hold every word the buttons show
- **Tests:** `AccountBriefingPromptTest` (8), `DisputeSummaryPromptTest` (5), `FollowupDraftPromptTest` (5), `RepAssistantControllerTest` (7), `PromptRunnerTest` (3), `PromptFormatTest` (7), `RecordLinesTest` (4), `SlaMilestonesTest` (3), and two more in `SensitiveTextTest`. 20 Jest tests in 4 suites, with accessibility checks
- **`docs/agent-governance.md`** (ST-17): every object and field each template reads, what never reaches a model, and the Einstein and Trust Layer settings as read on 2026-10-23
- 19 explainers (NFR-04). Decisions S-20 to S-22
- `manifest/rep-assistant.xml`: the Accord components Steward now deploys, retrieved as they were first (S-15)

### Changed in pull request #9
- `SensitiveText.redactForPrompt` removes email addresses and phone numbers as well as card numbers, for text on its way to a model
- `StewardTestData` gains the known-answer history the snapshot and briefing tests share, and `AccountSnapshotServiceTest` uses it
- Einstein setting `enableEinsteinGPTDeployPromptTemplatesAsActive` turned on, to activate deployed templates. New templates still arrived inactive (below)
- `jest.config.js` maps `lightning/actions` to a stub, for the quick actions' tests
- `docs/conventions.md` and `docs/requirements.md` for the rep assistant
- Version 0.5.0

### Pull request #9's validations
- **First** (`0Afaj00000ortiQCAQ`): 13 component errors, one cause. Salesforce has retired the flex capability type, so `CapabilityType='FlexTemplate://…'` stopped the three data classes compiling, and everything that depends on them failed. Removed: Prompt Builder matches the request's variable names to the template's inputs (S-20)
- **Second** (`0Afaj00000osgezCAA`): the Apex compiled; three errors, the templates' version identifiers. The org generates those, so a new template is deployed without one and retrieved afterwards
- **Third** (`0Afaj00000os6mpCAA`): 259 components, 159 of 159 tests, every class at 90% or more. The new classes run from 94.2% (`DisputeSummaryPrompt`) to 100%; seven of the eleven are at 100%

### Deployed, 2026-10-23
- Merged at 10:58 AM CT and quick-deployed as Steward CI (`0Afaj00000osZjyCAE`), with no second test run. The pull request changed components in `lwc/`, so the pipeline also republished the portal; none of the rep assistant's components are on it
- In the org: the three permission sets are in the three collections groups, which recalculated (status Updated), and the three templates exist, published
- **The templates arrived inactive**, though the same deploy turned on the setting that activates deployed templates, and an inactive template can't generate ("No active template version"). Pull request #10 retrieves them, now with the identifiers the org generated, and names each one's active version in source (`docs/conventions.md`)

### Pull request #10
- The templates as retrieved (`retrieve/3`), with the identifiers the org generated, and `activeVersionIdentifier` added to each. Validated (`0Afaj00000ovJCQCA2`, 159 of 159 tests), merged and quick-deployed (`0Afaj00000ouMkICAU`): the templates generate
- The Phase 5 docs: decisions S-20 to S-22, `docs/agent-governance.md`, 19 explainers, conventions, traceability, open items, this changelog

### Checked in the org, 2026-10-23
- Known answers: briefings for Sandra Barnett, Tanya Lattimore and Angela Coffey, every figure matching the records. A household with nothing on record gets one sentence
- Adversarial: a commitment's terms and a dispute's description aimed at the AI were reported as content and not followed, and nothing was recommended
- Follow-up: a Promise Made draft confirmed the promise's amount and date from its record, with no offers
- Persona access: Test Persona can read everything the templates read except the payment method, the processor reference, and a case's description, subject, account and contact
- One defect, fixed in pull request #11: a dispute summary called a commitment the data didn't flag a possible match

### Pull request #11
- `DisputeSummaryPrompt` marks every commitment its match rule doesn't flag "[Not flagged as a possible match.]", and `DisputeSummaryPromptTest` checks both markers
- The org checks' evidence in `docs/agent-governance.md`
- Validated (`0Afaj00000ovn8rCAA`, 159 of 159 tests), merged and quick-deployed (`0Afaj00000ovl74CAA`). Rerun: 00001035's summary now calls the commitment not flagged, and the adversarial dispute's summary is unchanged. The two adversarial test records were then removed

### The hand check, 2026-10-24
- Zana logged in as Test Persona at 8:10 PM CT, in the audit trail. Steps 1–4 went as written: Briefing, then Follow-up Draft asking for today's contact attempt first.
- **Step 5 found an Accord defect, DEF-08: Log Contact Attempt wasn't on the page.**
  - The action launches Accord's screen flow, and a user needs the Run Flows permission or access to that flow. Minimum Access and Accord's permission sets gave neither, so Lightning hid the action from every collections persona. Steward's Follow-up Draft needs a logged attempt, so it couldn't work for a real rep either.
  - Every earlier check ran as the admin, who can run any flow. Only a person in the console as the persona could have found this.
  - Fixed the same night in Accord's components, least privilege: the flow restricts access to enabled permission sets, and `PS_Collections_Core` grants that one flow. Recorded in Accord's CHANGELOG v1.0.2.
- Steps 5–8 still to finish.

### Pull request #13
- The three collections groups' descriptions said delete on Promise to Pay was muted (rep, specialist) or kept (supervisor). Accord's OBS-01 removed it from every persona; the descriptions now say so, and the rep group's names the Log Contact Attempt flow.
- **Commitments related list on the Residential Agreement layout** (Type, Value, Status). This finishes Accord's DEF-07: commitments were stamped with their account on Oct 14, but the list was never added. Recorded in Accord's changelog (NFR-09).
- `docs/screenshots/phase-4/`: the Phase 4 portal screenshots, indexed. They had been committed to Accord's repository by mistake.

### Found in the org while building
- **The flex capability type is retired** (above). Prompt Builder matches an Apex merge field to a flex template by the request's variable names
- **The org generates a template version's identifier**, and gave all three templates the same one, so it isn't a hash of the content
- **No Accord persona could read a case's subject, description, account or contact, and reps couldn't read a contact's email or phone numbers.** Steward's permission sets now grant what Zana chose (S-22)
- **This org has no Trust Layer data masking**: the setup page reads it as not provisioned, and Prompt Security's feature gate as closed. Steward keeps contact details out of prompts itself (S-20, `docs/agent-governance.md`)
- **The Turn on Einstein switch can be read** through the Einstein settings metadata (`enableEinsteinGptPlatform`: on), which Phase 1 couldn't do through the API
- **Accord's `Collection_Hold_Until__c` description was a copy of `Do_Not_Contact__c`'s.** Rewritten in Accord v1.0.2 (2026-10-24)

## v0.4 — 2026-10-21 — Phase 4: Customer portal

The customer portal: an LWR site where a household sees its balance, statements, payments and commitments, and opens and follows its disputes. It took three pull requests. #4 turned on Digital Experiences and added the workflow that brings the site's template-built configuration into the repo. #5 built the pages, the Apex behind them and the sharing that keeps each household to its own records. #6 closed two gaps found in the org after #5 deployed: the customer profiles' default access, and the disputes that existed before the household flow. All three went through validation, merge and the pipeline's deploy, and the result was checked in the org.

### Added in pull request #5
- **Six pages and a header** as Lightning web components on the site: My account, Statements, a statement's own page, What we promised you, Disputes and a dispute's own page (ST-01, ST-02, ST-06). A record's own page is a custom page with the ID in the address (S-17). Evidence is uploaded on the dispute's page
- **Controllers:** `PortalAccountController`, `PortalCommitmentsController` and `PortalDisputesController`, each taking the household from the login through `PortalHousehold`, never from the page (ST-12). `DisputeStatusService` reads a household's disputes for the portal now and the agent in Phase 6. `PortalFailure` turns any failure into a reference the customer can quote, with the details in the action log (NFR-07)
- **Sharing:** the `Customer_Household` sharing set, matched on a new `Case.Customer_Household__c` that `Case_BeforeSave_StampCustomerHousehold` stamps only on billing disputes, so Accord's default reviews stay internal (S-16). `Case_BeforeSave_StampDisputeAgreement` copies the disputed statement's agreement onto the case (S-19)
- **Access:** `PS_Steward_Customer`, and two custom profiles, Steward Customer and Steward Customer Login, instead of the standard external profiles (S-18)
- **96 custom labels** (`Steward_Portal_*`) hold every word a customer reads (ST-18)
- **Tests:** `PortalControllersTest` (12), `DisputeStatusServiceTest` (6) and `PortalHouseholdTest` (2) run as real customer users, and `AgentActionLoggerTest` gains one for references. 48 Jest tests in 10 suites, each state with an accessibility check (NFR-05). `PortalTestData` builds the customer users
- **Pipeline:** `scripts/check_personal_details.sh` and its 7 tests, run before a retrieve pushes and on every pull request. The deploy publishes the portal when a pull request changes what it shows. Jest runs with real label text and `@sa11y/jest`
- 18 explainers, one per new class and component (NFR-04). Decisions S-16 to S-19
- `scripts/apex/`: the two one-time scripts run after the deploy, for the backfill and the demo customers

### Changed in pull request #5
- `DisputeIntakeService` no longer reads or sets the dispute's agreement; the flow does (S-19)
- `AgentActionLogger.logForReference` returns a saved entry's number, and `StewardOutcome.Result` carries it as `reference` (NFR-07)
- `CommitmentReadService`: a comment on the S-08 read that Graph Engine flags
- `code-analyzer.yml` leaves Jest tests and the site bundle out of the scan; `.prettierignore` leaves the site bundle alone. Both are Experience Builder's or Node's, not deployed code
- `docs/conventions.md`, `docs/pipeline.md` and `docs/requirements.md` for the portal
- Version 0.4.0

### Pull request #5's validations
- **First** (`0Afaj00000oE785CAC`): two components refused. The household flow cleared its lookup with `$GlobalConstant.EmptyString`, which a before-save flow can't use on a lookup; it now leaves the value blank. The sharing set's description was over 255 characters
- **Second** (`0Afaj00000oE7PpCAK`): every component accepted; 14 of 99 tests failed. The org won't create users on the standard external profiles (S-18), and four tests looked up statements by a status Accord changes to In Dispute when a dispute opens
- **Third** (`0Afaj00000oE8FRCA0`): 5 of 108 tests failed. Customer licenses can't use service contracts, so every dispute a customer opened failed before it was saved (S-19). A file an external user uploads needs the site's network, as the upload area gives it
- **Fourth** (`0Afaj00000odYOQCA2`): 112 of 113 passed, every new class at 100%. One test read the new case's owner by name and got nothing; it now compares the queue's ID
- **Fifth** (`0Afaj00000odfg1CAA`): 114 of 114 tests, 203 components, every class at 90% or more. The lowest is `PaymentArrangementService` at 93.0%; `DisputeIntakeService` rose from 92.1% to 96.9% with the field-level refusal now tested

### Deployed and verified, 2026-10-21
- Merged at 8:27 PM CT and quick-deployed as Steward CI (`0Afaj00000odaQECAY`, no second test run). The pipeline then published the portal (background job `08Paj00001BNs04EAD`, finished 8:30 PM)
- In the org: the site is Live; the 11 components, both flows (Active) and both custom profiles were last changed by Steward CI
- Demo customers created with `scripts/apex/create-demo-customers.apex`: Sandra Barnett, Tanya Lattimore and Angela Coffey, each on Steward Customer with `PS_Steward_Customer`, usernames and emails on example.com, no welcome email

### Found in the org while building
- **The org won't create users on the standard external profiles** while "Allow using standard external profiles" is off. Custom profiles instead (S-18)
- **A profile created from source starts with its license's defaults**: the custom profiles got the same 25 objects as the standard ones. Pull request #6 switches each off (S-18)
- **A lookup is invisible to a user who can't read its object**, whatever their field access: with contacts switched off, customers lost `Account.Primary_Contact__c`, which the dispute needs. `PS_Steward_Customer` grants read on contacts
- **Customer licenses can't use service contracts.** The dispute's agreement is now stamped by a flow (S-19)
- **Accord sets a statement to In Dispute** when a dispute opens, so a test can't find a disputed statement by its old status
- **A before-save flow can't clear a lookup with `$GlobalConstant.EmptyString`**; an assignment with no value clears it
- **A sharing set's description is capped at 255 characters**
- **A file an external user uploads belongs to the site's network**, so a test of the upload sets it
- **Anonymous Apex runs with the runner's field access**, so it can't touch a field no profile can see. The backfill saves each dispute and lets the flow stamp it
- **The first retrieve brought back personal details** (the site's email sender and admin), now caught by `scripts/check_personal_details.sh`

### Pull request #6
- Both customer profiles switch off every object their license grants by default (S-18), and `PS_Steward_Customer` grants read on contacts, the one the portal needs
- `Case_BeforeSave_StampCustomerHousehold` also runs when a dispute's household doesn't match its account, so any save repairs it. `DisputeStatusServiceTest` proves it (S-16)
- `scripts/apex/backfill-customer-household.apex` saves each billing dispute once, for the flow to stamp
- **First validation** (`0Afaj00000odkFtCAI`): with the defaults off, customers couldn't read `Account.Primary_Contact__c`, so every dispute a customer opened failed; the tests' messages carried the logged reason. The new repair test also had to save in system mode
- **Second validation** (`0Afaj00000odmmLCAQ`): 115 of 115 tests, 203 components. The 115 are every local test in the org: Steward's 105 and 10 in the classes Salesforce added when Digital Experiences was turned on
- **Deployed** at 8:50 PM CT by quick deploy (`0Afaj00000odgKMCAY`). Nothing the portal shows changed, so the pipeline didn't republish it

### Checked in the org after #6, 2026-10-21
- Both customer profiles have no object permissions at all
- The backfill saved all 14 billing disputes. The admin can't read the field, by design, so the result was checked through access instead: of the 21 billing disputes and default reviews in the org, Sandra Barnett can read exactly one, her own open dispute, and Tanya Lattimore exactly one, her own closed dispute. Angela Coffey can read none. None of them can edit any, and none can see a default review (`UserRecordAccess`, S-16, ST-12)

### Added in pull request #4
- `settings/Communities.settings-meta.xml` turns on Digital Experiences (S-04, S-11). Salesforce can't turn it off again. It's been in the plan since Phase 1, and the admin approved it before the merge
- `.github/workflows/retrieve.yml` and decision S-15: configuration built outside source is retrieved as Steward CI into a branch of its own, and reaches `main` through a pull request (ST-13)

### Checked in the org before building (2026-10-18)
- All 88 households are owned by the admin, who holds the Collections Supervisor role, so their contacts can become customer users (S-04)
- Licenses free for customer users: 5 Customer Community and 5 Customer Community Login, none in use
- **The 31 commitments' terms (ST-02).** Each is one of four plain sentences in the rep's voice, such as "Rep agreed Lumenfield would cover the first 3 monthly payments." None holds internal notes, names or anything a customer shouldn't read. So the portal shows the terms as recorded, labeled that way, and no customer-facing field is needed

## v0.3 — 2026-10-18 — Phase 3: Apex services and the agent action log

The services the portal and the agent will call, with the action log the supervisor's dashboard will read. Every service checks the household first, in user mode, and returns outcome codes and figures rather than sentences. Every limit comes from Accord's policy records. Every write goes through Accord's own flows and rules. Only three operations run outside user mode, and each is a named decision with its own tests (S-08, S-09, S-14). No agent, portal or permission set yet: those are Phases 4 and 6. It went through end to end on 2026-10-18: pull request #2 passed its third validation, merged, was quick-deployed by the pipeline and was confirmed in the org.

### Added
- **Services, one per story:** `AccountSnapshotService` (ST-01), `CommitmentReadService` (ST-02, S-08), `StatementExplanationService` with `AmountDueComparison` (ST-03), `PaymentArrangementService` with `ArrangementEligibility` (ST-04), and `DisputeIntakeService` with `DisputeEvidenceCatalog` (ST-06)
- **Shared building blocks:** `HouseholdScope`, the household check every service runs first (ST-12). `PolicySettings`, the only reader of `Policy_Setting__mdt`. `StewardOutcome`, the outcome and reason codes. `SensitiveText`, which removes card numbers before anything is saved
- **The action log** (ST-11, S-09): the `Agent_Action_Log__c` object (six fields, Private, outcome as a required restricted picklist) and `AgentActionLogger`
- **Tests:** 12 test classes with 83 test methods, and `StewardTestData`. Known answers are asserted to the cent: $310.00 owed and $190.00 past due; an escalator step of exactly $3.48 at the agreement's anniversary; a $40 posted credit leaving $83.48. Each service has a scoping test that runs as a user who can't see the household, and a 200-record bulk test with its query count asserted
- **The 90% per-class coverage gate** (ST-13): `scripts/check_coverage.py`, its 12 tests in `tests/pipeline/`, and two new steps in `validate.yml`. The gate reads the coverage from the check-only deployment and fails closed. If it fails, the validation's job ID isn't kept, so the merge has nothing to deploy
- `code-analyzer.yml`: one documented change to Code Analyzer's defaults
- 14 explainers in `docs/explainers/`, one per class plus the test data factory (NFR-04)
- Decision S-14: dispute cases are saved in system mode, with the caller's create access applied to every other field

### Changed
- S-09 (agent outcomes logged to a custom object) is decided. S-08 is built and still confirmed in Phase 4
- NFR-01 names its three exceptions: S-08, S-09 and S-14
- `docs/conventions.md`: the real `PolicySettings` method names, the three exceptions, `HouseholdScope` first, request constructors limited to three parameters, the coverage gate, and `code-analyzer.yml`
- `docs/requirements.md`: a "Built so far" column in the traceability table. ST-04's notes record the minimum-amount floor and the rollback. The new policy settings are recorded as created in Phase 2, not Phase 3
- `docs/pipeline.md`: the coverage gate, Code Analyzer settings, and two new known limits
- Version 0.3.0

### Found in the org while building, and what it changed
- **`Case.AccountId` is read-only in all 42 profiles and permission sets** that include it, System Administrator among them. Accord's entitlement flow needs the account when a case is created. A user-mode insert would fail for every user, so the dispute insert is the one system-mode write, after the caller's own create access is applied to every other field (S-14).
- **Accord's `Out_of_Policy__c` formula** sends any promise for less than the past-due balance to approval. So the self-service minimum can be raised by its setting but never lowered below the full balance.
- **Accord's promise flow moves an out-of-policy promise to Pending Approval** instead of failing the save. `PaymentArrangementService` reads every new promise back, and rolls back any save that left one needing approval (GR-03).
- **Assignment rules don't run on cases Apex creates** unless asked. The dispute service sets the default-rule option, and a test checks the case lands in the Dispute Specialists queue.
- **`VR_Account_PrimaryContactRequired` blocks account updates** without a primary contact, including the roll-up recalculations statements trigger. Test households get their contact before anything else.
- **No household in Accord's data has an escalator step yet.** The known-answer test builds its own. Two demo statements are an open item for the agent phases.
- **No Salesforce license is free** for a test user. Access tests run as a Standard Platform User (six licenses free), which can read accounts only where sharing allows.

### Checked before delivery
- Prettier: every Apex file passes
- Every class and test type-checked against Accord's schema with the Apex language server, against a copy of the org's objects and fields: no errors
- Every query's fields checked against the org's schema
- Every field the code writes checked writable in the org, with no formula, roll-up or auto-number field assigned. Every required field on the objects the tests insert is set
- Field-level security for the System Administrator profile, which the pipeline user runs the tests with: every field the services read or write in user mode is open to it, apart from `Case.AccountId`, which S-14 handles
- Every active validation rule and record-triggered flow on the objects the tests insert read from the org, and the test data checked against each: 11 validation rules and 9 flows. The org has no Apex triggers or workflow rules
- Code Analyzer 5.16 on `force-app/`: 0 violations at any severity
- The coverage gate's 12 tests pass. Run against the real classes, it gates the 13 production classes and skips the 13 test classes
- Both workflows pass actionlint, including its shell checks

### What the first validation found, and the fix
The first run on the pull request (validation `0Afaj00000oBq9lCAC`, 2026-10-18) deployed all 36 components cleanly and ran 82 tests: 78 passed and 4 failed. The ones that passed include every check on Accord's automation: the assignment rule routing disputes to Dispute Specialists, the SLA entitlement, Accord's credit math ($83.48), the approval rollback, and all five 200-household bulk tests.
- **4 failures, one cause.** All four were in `AgentActionLoggerTest`: "No such column" when a test read back the new log fields. The fields are new, so no profile or permission set has access to them yet. Supervisors get it in Phase 6. A plain query in a test checks field-level security, so the pipeline user couldn't read them. The required Outcome field was readable, which is what pinned it down. **Fix:** the test's read-backs use `WITH SYSTEM_MODE`, because they check what was stored, not who can see it. This is now a convention.
- **The coverage gate's first catch.** The same run measured `PaymentArrangementService` at 87.1% (88 of 101 lines). The gate would have stopped it even if every test had passed. A save the platform rejects had no test. **Fix:** a new test sends an amount too large for the currency field. The save fails, and the test proves the failure is reported as `SAVE_FAILED` with the platform's message, not thrown. That brings the class to 93% (94 of 101). The remaining seven lines are a safety net: they run only if Accord's flow gives a different answer when the same promise is saved a second time. Accord's current rules judge each promise on its own, so that can't happen today. But if it ever did, the net is what stops a promise needing approval from being left behind.
- **One test took two minutes.** `AccountSnapshotServiceTest.outOfReachHouseholdsAreNotFound` inserted an account and then a user in the same test. Every other test that creates a user took about a second. **Fix:** the account moved to the test setup.
- **A detail for S-14.** `Case.AccountId` is read-only in the System Administrator profile's field permissions, but the platform's own create check (`Security.stripInaccessible`) left it in place for the pipeline user. So for an admin, the field permission isn't the whole story. Phase 6 checks what the agent user gets. S-14 is unchanged, because it gives the same result either way.
- Coverage per class from this run, before the fix: 100% for 9 classes; `AccountSnapshotService` 99.0%, `DisputeEvidenceCatalog` 98.3%, `DisputeIntakeService` 92.1% and `PaymentArrangementService` 87.1%. Run on these real numbers, `scripts/check_coverage.py` fails `PaymentArrangementService` and passes the rest.

### The second validation, and one more fix
The second run (validation `0Afaj00000oBuQHCA0`, 2026-10-18) passed 82 of 83 tests:
- The four log tests passed.
- The two-minute test took 1.4 seconds, and the whole test run took 114 seconds instead of 227.
- The one failure was the new test. Its amount, 1,000,000,000,000,000, has 16 digits, and the currency field holds 16 before the decimal point. So the promise saved, and the test found `COMPLETED` where it expected `FAILED`. The field's definition in the org (precision 18, scale 2) confirms it.

**Fix:** the test now uses 21 digits.

### Verified in the org
- Validation `0Afaj00000oBwtVCAS`, the third run on pull request #2: check-only with local tests, run as Steward CI, 2026-10-18 11:00–11:03 AM CT. 36 of 36 components and 83 of 83 tests passed, 0 errors
- Coverage per class from that run, every class above the gate: 100% for 9 classes; `AccountSnapshotService` 99.0% (108 of 109 lines), `DisputeEvidenceCatalog` 98.3% (58 of 59), `PaymentArrangementService` 93.0% (94 of 101) and `DisputeIntakeService` 92.1% (153 of 166). 97.4% across all 864 lines. Run on these numbers, `scripts/check_coverage.py` passes all 13 classes
- The pull request's whole `validate` run passed, coverage gate included. The deploy workflow only goes ahead when it finds a successful `validate` run for the pull request's final commit, and the job ID that run keeps once the gate has passed
- Deployment `0Afaj00000oBxXpCAK`: run as Steward CI when pull request #2 merged, 11:04 AM CT. 36 of 36 components in 7 seconds, no tests run, and the same 60-file package as the validation. That's the quick deploy; the fallback would have run all 83 tests again. Phase 2 couldn't tell the two paths apart, because it had no Apex
- In the org: the 26 classes (13 production classes, 12 test classes and `StewardTestData`), Active at API 68.0, and `Agent_Action_Log__c` with its six fields, all last changed by Steward CI at 11:04 AM CT
- What merged is what was validated: the merge commit's files are identical to the pull request's final commit
- Test time: 149 seconds in all. The slowest test, opening 200 disputes, took 32 seconds. The one that took two minutes in the first run took 1.6 seconds
- Lines no test reaches yet, 22 of 864. Seven are `PaymentArrangementService`'s safety net, described above. Thirteen are in `DisputeIntakeService`: the refusal for a caller who can create cases but not one of the dispute fields, a save the platform rejects, and a description longer than the field. Phase 3's tests refuse a user with no Case access at all. A user with Case access but one field missing needs a Salesforce license, and none is free, so Phase 6 checks that refusal with the agent user

## v0.2 — 2026-10-17 — Phase 2: Pipeline

Every org change now goes through a pull request that's validated against the org before it can merge. The first change went through end to end on 2026-10-17: validated on pull request #1, merged, deployed by the pipeline, and confirmed in the org.

### Added
- `.github/workflows/validate.yml`: on every pull request, a Prettier check, Jest (once components exist), Code Analyzer with critical and high findings blocking, sign-in as the Steward CI user by JWT, and a check-only deployment with local Apex tests. The validation's job ID is kept for 10 days
- `.github/workflows/deploy.yml`: on a merge that changes `force-app/`, finds the pull request's passing validation and quick-deploys it, falling back to a fresh deploy with the same tests if Salesforce won't accept the quick deploy. Refuses changes that didn't come through a validated pull request
- `docs/pipeline.md`: how a change reaches the org, what protects each step, the secrets, known limits, key rotation, and the setup steps
- The first change sent through the pipeline: three new `Policy_Setting__mdt` records, `Self_Service_Broken_Promise_Limit` (2), `Self_Service_Min_Coverage_Pct` (100) and `Production_Guarantee_Pct` (90). Moved up from Phase 3 because they're small, real and harmless until Phase 3 code reads them
- `package-lock.json`, so the pipeline installs exactly the same tool versions every time
- Decisions S-12 (the pipeline signs in as its own user, with a certificate) and S-13 (pull requests for anything that deploys; docs can go straight to `main`)

### Changed
- ST-13 criteria: the quick-deploy fallback and the refusal of direct pushes are now acceptance criteria
- Prettier checks code files only. Metadata XML stays exactly as Salesforce retrieves it, so retrieves don't create formatting noise
- `@prettier/plugin-xml` removed; nothing uses it now

### Checked before delivery
- Both workflows pass actionlint, including its shell checks
- Code Analyzer 5.16 on `force-app/`: 0 violations
- The three records convert to Metadata API format cleanly (one `CustomMetadata` type, API 68.0)

### Verified in the org
- Validation `0Afaj00000o9QheCAE`: check-only with local tests, run as Steward CI; 3 of 3 components, 0 errors
- Deployment `0Afaj00000o9ZplCAE`: run as Steward CI after pull request #1 merged; 3 of 3 components, 0 errors
- `Self_Service_Broken_Promise_Limit` = 2, `Self_Service_Min_Coverage_Pct` = 100 and `Production_Guarantee_Pct` = 90 exist, all stamped 2026-10-17 8:04 PM CT
- The org's deployment history names Steward CI, not the admin, for both runs (S-12)
- `main` is protected by the `Protect main` ruleset: a pull request and a passing `validate` check are required, the branch has to be up to date, and the admin can bypass for doc commits (S-13)

### What broke during setup, and the fix
- **"client identifier invalid", twice.** Locally, the sign-in test was run with the placeholder `PASTE_CONSUMER_KEY` still in it; the test now prompts for the key instead. In the first validation run, the `SF_CLIENT_ID` secret held something other than the key, most likely from a clipboard mix-up while entering secrets. Re-entering each value right after copying it fixed it, and the re-run passed without a commit.
- **The refresh token policy wouldn't save.** "Expire refresh token if not used for" is capped at 30 days; "Expire refresh token after specific time" accepts 90. The setup steps now name the right option.
- **The OAuth scopes weren't visible.** They only appear after **Enable OAuth** is ticked. The setup steps now say so.
- **No repository-level push protection setting** appeared for this personal public repo. GitHub's account-level push protection is on by default for public repositories, so the step was dropped.
- **A tag named `Push-orgin` was created instead of `v0.1`.** It's deleted and replaced with `v0.1` and `v0.2` as part of closing this phase.

## v0.1 — 2026-10-16 — Phase 1: Requirements

Stories, guardrails and decisions, written against what's actually in the org (read 2026-10-16) rather than against assumptions.

### Added
- `docs/requirements.md`: 18 stories (11 Must, 6 Should, 1 Could), each with Given / When / Then criteria and a negative case. Every agent story also has an adversarial case. Six agent guardrails (GR-01 to GR-06), ten non-functional requirements, a table of what customers, the agent and reps can each see, the Accord policy values and dispute evidence the stories depend on, and a traceability table
- `docs/decision-log.md`: S-01 to S-11. Five decided; six proposed, each with the phase that confirms it
- `docs/conventions.md`: naming and coding standards for Apex, Lightning web components, the agent, prompt templates, integrations, Data 360 and Git
- `docs/brief.md` and `docs/open-items.md`
- Project scaffold: `sfdx-project.json` (API 68.0), `.forceignore`, `.gitignore`, `package.json` and Prettier settings for later phases, pull request template, explainer template

### Findings that shaped the requirements
- **Commitments can't reach customers directly.** They're detail records of the opportunity, and customer licenses can't be given opportunity access. They'll go through a scoped read service instead (S-08), filtered on `Commitment__c.Account__c`, the lookup added by Accord's DEF-07.
- **Accord's policy already covers most of what the agent needs:** the 30-day promise window, 3 grace days, credit limits and 16 evidence requirements across 8 dispute reasons. Steward reads them rather than copying them (S-03). Three new policy values are proposed for self-service rules and the production guarantee.
- **Ready in the org:** Omni-Channel is on, Messaging is available, and the new Agentforce Builder with Agent Script is available. No agents exist yet.
- **Off for now:** Digital Experiences (Phase 4), Dev Hub (stays off, S-05), and the Trust Layer's master Prompt Security setting (decided in Phase 6).
