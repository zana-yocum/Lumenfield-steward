# Decision Log — Steward

The decisions that shape Steward, the options considered, and why one was chosen. Same format as Accord's D-01 to D-10.

**Status:** **Decided**, or **Proposed**: a starting position that's confirmed or changed, with evidence from the org, in the phase shown.

| ID | Decision | Status |
|---|---|---|
| S-01 | The service agent runs as its own least-privilege user | Proposed · Phase 6 |
| S-02 | Salesforce asks the payment provider; the provider never calls Salesforce | Proposed · Phase 7 |
| S-03 | Apex for agent actions; Accord's flows keep the policy | Decided |
| S-04 | Customer Community licenses with sharing sets | Decided · confirmed in Phase 4 |
| S-05 | The pipeline validates against the org; no scratch orgs | Decided |
| S-06 | What the agent may never do | Decided |
| S-07 | The model never chooses whose data to read | Decided · mechanism confirmed in Phase 6 |
| S-08 | Customers see commitments through a scoped read service | Decided · built in Phase 3, confirmed in Phase 4 |
| S-09 | Agent outcomes are logged to a custom object | Decided |
| S-10 | The agent's definition lives in Git and ships through the pipeline | Decided |
| S-11 | The portal is an LWR site | Decided · built in Phase 4; chat placed in Phase 6 |
| S-12 | The pipeline signs in as its own user, with a certificate | Decided |
| S-13 | Pull requests are required for anything that deploys | Decided |
| S-14 | Dispute cases are saved in system mode, with the caller's create access applied to every other field | Decided |
| S-15 | Configuration built outside source is retrieved by the pipeline | Decided |
| S-16 | Customers see disputes through `Customer_Household__c`, not the case's account | Decided |
| S-17 | A record's own portal page is a custom page with the ID in the address | Decided |
| S-18 | Customers use custom profiles, not the standard external profiles | Decided |
| S-19 | A dispute's agreement is stamped by a flow, not set by the caller | Decided |
| S-20 | The rep assistant's templates read records in Apex, with the user's own access | Decided |
| S-21 | The assistant's buttons check before any model runs; the follow-up opens in the email composer | Decided |
| S-22 | Steward permission sets close the collections groups' access gaps | Decided |

---

### S-01 — The service agent runs as its own least-privilege user
**Status:** Proposed · confirm in Phase 6

**Context:** Every agent action runs as a user. Whatever that user can reach, a cleverly worded conversation might reach too.

**Options**
1. Accept the agent user and permissions the setup wizard creates by default.
2. A dedicated agent user on an Einstein Agent license, named in the Agent Script, with one Steward permission set and nothing inherited. **← starting position**
3. Run every action as the logged-in customer.

**Why:** Option 2 turns the agent's reach into a short list someone can review line by line (ST-12). Option 1 leaves that list to defaults nobody chose. Option 3 sounds safest, but service agent actions run as the agent user, and the customer's identity still has to be carried into each action deliberately (S-07).

**Consequences:** `PS_Steward_Agent` is the whole of the agent's access, listed in `docs/security-model.md`. The agent has to serve any household, so it gets access to Residential Agreement accounts through a criteria-based sharing rule, not View All, and Organization accounts stay out of reach. Any new action that needs more access needs an entry here first.

---

### S-02 — Salesforce asks the payment provider; the provider never calls Salesforce
**Status:** Proposed · confirm in Phase 7

**Context:** A customer pays on the provider's checkout page. Salesforce needs to learn about each completed payment once, reliably.

**Options**
1. **Webhook:** the provider calls a public Salesforce endpoint when a payment completes. Fast, but it opens a public door into the org that needs a site user and signature verification to secure.
2. **Polling:** Salesforce checks for completed payments once when the customer returns to the portal, and again on a schedule as a safety net. **← starting position**
3. **Salesforce Payments**, the native product: less code, but the work becomes configuring its checkout and merchant onboarding rather than building an integration.

**Why:** Polling leaves no public surface to secure and works within Developer Edition. Its cost is a delay of up to one schedule interval when a customer never returns to the portal, which is acceptable for a monthly lease payment. The integration skills it exercises (credentials, callouts, async reconciliation, idempotency) carry over to any provider.

**Consequences:** `PaymentReconciliationJob` runs on a schedule. Duplicates are prevented by upserting on `External_Reference__c`, and every request that creates something at the provider sends an idempotency key. A production build would revisit webhooks, with signature checks, for real-time posting.

---

### S-03 — Apex for agent actions; Accord's flows keep the policy
**Status:** Decided

**Context:** Agent actions can be flows, Apex or prompt templates. Accord already enforces its policy in flows, validation rules and an approval process.

**Options**
1. Flows for every action.
2. Apex for every action that reads or writes data; prompt templates only for wording. **← decided**
3. Rebuild Accord's rules inside the actions so the agent can explain them.

**Why:** The agent needs structured results (a list of reasons with amounts, eligibility with a reason code), bulk-safe queries, and record scoping that can be unit-tested, and Apex does all three cleanly. Writes stay thin: the service inserts the record and Accord's automation applies the policy, so there's one source of truth. Option 3 would create a second copy of every rule, and the copies would drift.

**Consequences:** Each action is a small `@InvocableMethod` class that calls a service class. Where a service checks a rule before saving (the 30-day window, for example), the check exists only to give the customer a clear answer first; the save still goes through Accord's rule, and both read the same `Policy_Setting__mdt` value.

---

### S-04 — Customer Community licenses with sharing sets
**Status:** Decided · confirmed in Phase 4

**Context:** Customers must see only their own household. The org has five Customer Community and five Customer Community Plus licenses.

**Options**
1. **Customer Community:** no roles; record access through sharing sets matched on the user's account. **← starting position**
2. **Customer Community Plus:** adds roles, sharing rules and reports.

**Why:** "The household" maps exactly onto a sharing set (the record's account is the user's account), and the master-detail records follow the account. Plus adds role-based sharing that nothing here needs.

**Consequences:** Two limits shape the design. Customer licenses can't be given opportunity access (S-08), and each customer user can reach at most 10 custom objects; the portal needs three (Billing Statement, Lease Payment, Promise to Pay). Account owners must have a role before a contact can become a customer user, which is checked in Phase 4.

**Confirmed in Phase 4.** All 88 households are owned by the admin, who holds the Collections Supervisor role, so their contacts can become customer users; the pipeline user has no role, so tests give it one first (`PortalTestData`). The `Customer_Household` sharing set gives a customer their account, and through it their statements, payments and promises, and their billing disputes, matched on `Customer_Household__c` (S-16). Customers use custom profiles on these licenses, not the standard ones (S-18). Two more limits surfaced while building: customer licenses can't use service contracts (S-19), and a file an external user uploads belongs to the site's network.

---

### S-05 — The pipeline validates against the org; no scratch orgs
**Status:** Decided

**Context:** Every pull request needs a real org to validate against. Dev Hub isn't enabled, and Steward depends on Accord's metadata, Agentforce, Experience Cloud and Data 360.

**Options**
1. A scratch org per pull request: needs Dev Hub, a full deploy of Accord each time, and features scratch orgs may not support.
2. A check-only deploy with local Apex tests against the Developer Edition org, then a quick deploy on merge. **← decided**
3. Deploy from a laptop with the CLI, as Accord did.

**Why:** Option 2 tests every change against the real data model with no new infrastructure. Option 3 is what ST-13 exists to replace.

**Consequences:** The pipeline signs in with a certificate (JWT) through an External Client App, set up in Phase 2. Validation and deployment hit the same org; a real team would validate in a sandbox first. That's recorded as a known limit, not hidden. Confirmed on 2026-10-18: the Phase 3 merge quick-deployed validation `0Afaj00000oBwtVCAS` in 7 seconds, with no second test run (deployment `0Afaj00000oBxXpCAK`).

---

### S-06 — What the agent may never do
**Status:** Decided

The agent never:
- approves, posts or waives a credit or a fee
- creates anything that would need a supervisor's approval
- changes a status, an owner or a policy value
- reads or repeats payment method details, processor references or card numbers
- reads or acts on any household other than the verified one
- gives legal or tax advice
- promises anything that isn't already on the customer's records

**Why:** Each line is something a collections rep can't do either, or something no one should do in a chat. The list is short enough to test every line (ST-12, ST-16).

**Consequences:** Each line maps to at least one adversarial test case in Phase 10.

---

### S-07 — The model never chooses whose data to read
**Status:** Decided · mechanism confirmed in Phase 6

**Context:** Anything a customer types in a chat reaches the model, including another customer's name or record ID. If an action accepted an account ID from the model, a well-crafted message could point it at someone else's account.

**Options**
1. Let the model pass record IDs into actions, and rely on instructions to keep it honest.
2. Set the customer's identity from the authenticated session when the conversation starts, hold it where the model can't change it, and have every action use it and re-check that records belong to it. **← decided**
3. Verify customers inside the chat with a one-time code.

**Why:** Option 1 makes security depend on the model following instructions, which is exactly what injection attacks target. Option 2 makes it structural: no action has an account parameter to abuse. Option 3 suits a chat open to the public; Steward's chat sits behind the portal login, so the login is the verification.

**Consequences:** Hidden pre-chat fields are set by the browser, so they don't count as identity. The identity must come from the platform's link between the logged-in user and the conversation, confirmed in Phase 6. Every action re-checks that any record ID it's given belongs to the verified account (ST-12).

---

### S-08 — Customers see commitments through a scoped read service
**Status:** Decided · built in Phase 3, confirmed in Phase 4

**Context:** Commitments are detail records of the opportunity, so seeing one requires access to its opportunity. Customer licenses can't be given opportunity access, and customers shouldn't see the deal record anyway.

**Options**
1. Change Commitment's relationship to the opportunity so commitments can be shared on their own. That rebuilds Accord's data model (NFR-09).
2. Copy commitments into an object customers can see: two copies that can drift.
3. A read service that runs in system mode, finds commitments by `Account__c` for the verified household only, and returns five fields. **← starting position**

**Why:** Option 3 keeps one source of truth and exposes the minimum. Accord's DEF-07 lookup (`Commitment__c.Account__c`) makes the household filter a single field.

**Consequences:** This is one of three named exceptions to user mode (NFR-01), with S-09 and S-14. It lives in an inner class with a comment citing S-08, and tests prove that a customer, the agent, and a portal call carrying another household's ID each get only their own household's commitments.

**Built in Phase 3** as `CommitmentReadService`. The user-mode household check runs first, and the elevated read is a single query in an inner `Elevated` class that selects only the five customer fields. `CommitmentReadServiceTest` runs as a user with no access to commitments or opportunities: given read access to one household, the user gets that household's commitments through the service, while the user's own query on `Commitment__c` is blocked and a second household stays not found. All seven of its tests passed in the org on 2026-10-18 (validation `0Afaj00000oBwtVCAS`). Phase 4 confirms in the org that customer licenses can't be given opportunity access, which is what makes the service necessary.

**Confirmed in Phase 4.** The org's standard Customer Community Login User profile lists the 25 objects its license allows, and Opportunity isn't one of them (read 2026-10-18). The What we promised you page reads commitments through this service only, and `PortalControllersTest` proves a customer user sees their own household's commitment, with its terms as recorded, and not another household's.

---

### S-09 — Agent outcomes are logged to a custom object
**Status:** Decided · confirmed in Phase 3

**Context:** Supervisors need to see what the agent did, including requests it declined, where nothing else in the org changes (ST-11).

**Options**
1. Built-in Agentforce analytics: rich conversation data, but it records what was said, not which policy decided the outcome.
2. `Agent_Action_Log__c`: one record per action, written by the action. **← starting position**
3. Platform event logging only: nothing to report on afterwards without extra storage.

**Why:** A declined request is a business event, and the reason ("date outside the 30-day window") is what a supervisor needs. Only the action knows it. Option 2 turns it into a reportable record.

**Consequences:** Every action writes a log record, failures included, and never stores sensitive text. Built-in analytics, where available, supplement it. Payment callouts log failures to `Integration_Log__c` the same way.

**Confirmed in Phase 3.** `Agent_Action_Log__c` has six fields: account, action, outcome, reason code, details and conversation ID. The outcome is a required, restricted picklist with exactly the four outcome codes' labels, so the dashboard can't drift from what the services return. `AgentActionLogger` writes in system mode from an inner class without sharing. That's the second named exception to user mode (NFR-01), and it's deliberate: a declined request about an account the caller can't see must still be recorded, and the agent user then needs no access to the log object at all. Reading works the other way: the object is Private, and only supervisors and admins get read access, through permission sets in Phase 6. Card numbers are removed before saving (`SensitiveText`), and a log that fails to save is reported, never thrown, so logging can't break the action a customer is waiting on. All eight logger tests passed in the org on 2026-10-18 (validation `0Afaj00000oBwtVCAS`), including the one where the caller can't see the account.

---

### S-10 — The agent's definition lives in Git and ships through the pipeline
**Status:** Decided

**Context:** New agents are built in the Agentforce Builder with Agent Script. The script is metadata (`AiAuthoringBundle`) that can be retrieved, reviewed in a pull request, and deployed. The legacy Setup builder no longer creates new agents.

**Options**
1. Build and change the agent only in the builder.
2. Keep the Agent Script in the repo, deploy it through the pipeline, then publish and activate a version from the release step. **← decided**
3. Keep both the script and the runtime metadata it generates (`GenAiPlannerBundle`) in the repo and deploy them together.

**Why:** Option 2 puts agent changes through the same review and tests as code (ST-13), with a readable diff of the script. Option 3 skips the publish step but versions generated files nobody should edit by hand.

**Consequences:** Edits made in the builder are retrieved and committed the same day. A version is activated only after the agent test suites pass.

---

### S-11 — The portal is an LWR site
**Status:** Decided · built in Phase 4; the chat is placed in Phase 6

**Context:** Experience Cloud sites are built on either Lightning Web Runtime (LWR) or the older Aura framework.

**Options**
1. **Aura** (Customer Service template): more ready-made components.
2. **LWR** (Build Your Own): faster pages built from Lightning web components, and the direction of Salesforce's newer Experience Cloud features. **← starting position**

**Why:** Steward's portal pages are mostly its own components (ST-01, ST-02, ST-15), so Aura's ready-made components matter less than LWR's speed.

**Consequences:** Phase 4 confirms everything the portal needs, including the Enhanced Chat deployment, works in an LWR site before building it.

**Confirmed in Phase 4.** The site is Build Your Own (LWR), and every page is Steward's own Lightning web components on custom pages (S-17), with LWR's navigation, page references and file upload. The site's configuration lives in source and is retrieved by the pipeline (S-15). Enhanced Chat is added to an LWR site with Experience Builder's Embedded Messaging component, which Phase 6 places once the agent and its messaging deployment exist.

---

### S-12 — The pipeline signs in as its own user, with a certificate
**Status:** Decided

**Context:** The pipeline has to sign in to the org with nobody there to type a password.

**Options**
1. An SFDX auth URL from the admin's own login, stored as one secret. Quickest, but it's the admin's session: if the admin's access changes, the pipeline breaks, and every deployment looks like a change the admin made by hand.
2. JWT bearer flow through an External Client App, signed in as a dedicated Steward CI user that's pre-authorized through one permission set. **← decided**

**Why:** The private key lives only in a GitHub secret and, for a moment, in the runner's temporary folder; the certificate in Salesforce can be replaced without touching anyone's login. A separate user makes pipeline deployments easy to tell apart from manual changes in the Setup Audit Trail, and only users holding `PS_Steward_CI` can use the app.

**Consequences:** The Steward CI user takes the org's last free Salesforce license. It has the System Administrator profile, because deployments need that access; what limits it is that only this one user can use the app, and only with the key. The key is generated outside the repo folder and rotated by uploading a new certificate (`docs/pipeline.md`). Confirmed on 2026-10-17: the org's deployment history shows Steward CI, not the admin, as the user behind the first validation and deployment.

---

### S-13 — Pull requests are required for anything that deploys
**Status:** Decided

**Context:** Branch rules can require a pull request for every change to `main`, or let the admin commit some changes directly.

**Options**
1. Pull requests for everything, including the open-items updates written at the end of every sitting.
2. Pull requests for org changes; documentation can be committed straight to `main` by the admin. **← decided**

**Why:** The rule that matters is that nothing reaches the org without validation. The deploy workflow enforces it directly: it runs only when `force-app/` changes, and it refuses any change that didn't come through a pull request with a passing validation. Documentation doesn't touch the org.

**Consequences:** The ruleset on `main` requires a pull request and the `validate` check, with the repository admin allowed to bypass it for doc commits. A direct push that changes `force-app/` fails the deploy workflow with a message saying why. Doc commits put open pull requests behind `main`, so they need updating before they merge.

---

### S-14 — Dispute cases are saved in system mode, with the caller's create access applied to every other field
**Status:** Decided

**Context:** A dispute has to be created on the household's account. The account is what ties the case to the customer, and Accord's `Case_BeforeSave_StampEntitlement` flow uses it to find the SLA entitlement while the case is being created. But `Case.AccountId` is read-only in all 42 profiles and permission sets in the org that include it (read 2026-10-18). So the agent and customer users Steward adds can't be counted on to set it in user mode. System Administrator is the odd one out. Its field permission says read-only too, but in the first Phase 3 validation the platform's own create check, `Security.stripInaccessible`, let the pipeline user set the field.

**Options**
1. Grant edit on `Case.AccountId` in the agent's permission set in Phase 6. That widens access on a field no profile or permission set can edit today. It also isn't limited to new cases: anyone with edit can move an existing case to another account.
2. Leave the account blank and rely on the contact. The household would then depend on the contact's account rather than on the verified household (S-07), and the SLA would depend on the platform filling in the account before Accord's flow looks for the entitlement.
3. Save the case in system mode, after applying the caller's own create access to the Case object and to every other field it sets (`Security.stripInaccessible`). **← decided**

**Why:** Option 3 changes nobody's access, and it works however the platform answers for a given user. All system mode adds is the one field the agent and customers can't count on setting, on a record the caller is otherwise allowed to create in full. The account it sets is always the verified household, already checked in user mode. Option 1 would give the agent a standing ability to move cases between households, which is exactly the reach S-06 rules out.

**Consequences:** `DisputeIntakeService` refuses with `ACCESS_DENIED`, and saves nothing, when the caller can't create cases or set any field other than the account. A test proves it for a user with no Case access, and it passed in the org on 2026-10-18. The field-level refusal had no test in Phase 3, because no license was free for a user who can create cases but not one of the dispute fields. Phase 4 tests it with a customer user whose permission set can't set the dispute reason: refused with `ACCESS_DENIED`, nothing saved, and the log names the field (`PortalControllersTest`, passed in the org on 2026-10-21). This is the third named exception to user mode (NFR-01), after S-08 and S-09. It's one statement with a comment citing S-14. The agent user still needs Case create and access to the dispute fields, and read access through sharing to see the case number once the case is in the queue (Phase 6). Phase 6 also checks what the agent user's create access to `Case.AccountId` really is. If the agent can set it, or edit on it is granted for another reason, the insert can move to user mode and this exception can be removed.

---

### S-15 — Configuration built outside source is retrieved by the pipeline
**Status:** Decided

**Context:** Some configuration doesn't start in source. The portal site is created from Salesforce's Build Your Own (LWR) template, which generates its pages, theme and settings, and a later change might be made in Experience Builder or Setup. ST-13 requires all of it in the repo the same day, so the repo stays the record of what's in the org.

**Options**
1. Retrieve on a laptop with the Salesforce CLI and commit by hand, as Accord did.
2. A workflow that retrieves as Steward CI and pushes the result to a branch of its own. **← decided**

**Why:** Option 2 uses the same identity and tool versions as the deploys, leaves a run log for every retrieve, and needs nothing installed or signed in on anyone's computer. Option 1 depends on whoever runs it having the CLI signed in to the right org.

**Consequences:** `retrieve.yml` runs by hand, on the branch that holds the manifest, and pushes `retrieve/<run number>`. It can't change `main`: the ruleset doesn't let it. GitHub doesn't start workflows from pushes made with its own token, so a retrieved branch doesn't validate by itself. Its files reach `main` in an ordinary pull request, which does.

---

### S-16 — Customers see disputes through `Customer_Household__c`, not the case's account
**Status:** Decided

**Context:** A sharing set gives customers records whose field matches their user's account. Matching cases on `AccountId` would also give them Accord's Default Review cases: collections' internal reviews of a delinquent household, opened on the same account. Customers may see their billing disputes and nothing else on Case (ST-12, "What each audience can see").

**Options**
1. Match on `Case.AccountId`. Every default review on the household would reach the portal.
2. Match on `Case.ContactId`. Default reviews name the primary contact too, so the same problem.
3. A lookup to the account that only billing disputes carry: `Customer_Household__c`, stamped by a before-save flow from `AccountId` when the record type is Billing Dispute, and cleared on any other case. **← decided**

**Why:** A sharing set can only match a field, not a record type, so option 3 gives it a field that means exactly "this case is the household's dispute". The flow runs before the save, so it costs no extra DML, and only when a case is created or its record type or account changes.

**Consequences:** `Case_BeforeSave_StampCustomerHousehold` keeps the field right, and a case that stops being a billing dispute leaves the portal. The flow also runs whenever a dispute's household doesn't match its account, so any save repairs one. That's how the 14 billing disputes from before the flow are backfilled: each is saved once. The field can't be set directly, even by an admin: no profile or permission set has access to it. `DisputeStatusServiceTest` runs as a customer: the household's two disputes are visible, its default review and another household's dispute aren't, by list or by ID, and the flow stamps and clears the field.

---

### S-17 — A record's own portal page is a custom page with the ID in the address
**Status:** Decided

**Context:** The portal shows one statement or one dispute on its own page. An LWR site offers object pages, a detail, list and related-list page per object, or custom pages that a component fills.

**Options**
1. Object pages for Billing Statement and Case: six pages, with the record ID in the path.
2. Two custom pages, `statement` and `dispute`, with the ID in the address's query (`?recordId=…`). **← decided**

**Why:** The portal's components never show a record through the platform's record pages. Every read goes through a household-scoped controller (ST-12), so an object page's record binding adds nothing. Two pages instead of six, and no list or related-list pages to hide or secure.

**Consequences:** `portalShared` builds the links (`recordPage`) and reads the ID back (`recordIdFrom`). Changing the ID in the address gets the no-access message, exactly as it would on an object page. If a standard record component is ever wanted on the portal, object pages can be added then.

---

### S-18 — Customers use custom profiles, not the standard external profiles
**Status:** Decided

**Context:** The second Phase 4 validation found that the org won't create users on the standard external profiles: "Allow using standard external profiles for self-registration, user creation, and login" is off, and Salesforce recommends custom profiles for external users instead.

**Options**
1. Turn the setting on and use Customer Community User and Customer Community Login User. Those profiles carry access Steward doesn't want: on 2026-10-18 the login profile had create and edit on cases, contracts, orders, assets, entitlements and work orders, among 25 objects.
2. Two custom profiles: Steward Customer (Customer Community) for customers and Steward Customer Login (Customer Community Login) for test customers. All of Steward's access comes from `PS_Steward_Customer`. **← decided**

**Why:** Least privilege, the same idea as NFR-01, applied to profiles. The setting stays off, as Salesforce recommends. Test customers use login licenses, so a test never needs one of the five member licenses the demo customers hold.

**Consequences:** The sharing set and the site's members list the two custom profiles. A new customer user gets Steward Customer and `PS_Steward_Customer`. `PortalTestData` creates test customers on Steward Customer Login.

**Found after the first deploy.** A profile created from source starts with its license's defaults, not with nothing: on 2026-10-21 both custom profiles had the same 25 objects as the standard ones, create and edit on cases among them. Each of the 25 is now switched off explicitly in the profile's source, so the profiles grant nothing and `PS_Steward_Customer` is the only source of a customer's access. Switching them off showed one the portal relies on: read on contacts. A dispute names the household's primary contact, and a customer can't read a lookup to contacts, even with access to the field, unless they can read contacts. `PS_Steward_Customer` now grants it, read only.

---

### S-19 — A dispute's agreement is stamped by a flow, not set by the caller
**Status:** Decided

**Context:** `DisputeIntakeService` copied the disputed statement's agreement onto the case (`Service_Contract__c`), reading it in user mode. Customer licenses can't use service contracts: the standard customer profiles have no access to the object. In the third Phase 4 validation, every dispute a customer opened failed before it was saved.

**Options**
1. Read the agreement in system mode inside the service: a fourth named exception to user mode (NFR-01).
2. A before-save flow copies the disputed statement's agreement onto every Billing Dispute, so the caller never touches the field. **← decided**

**Why:** The agreement isn't a choice the caller makes; it follows from the statement. Deriving it in a before-save flow costs no extra DML, adds no exception to user mode, and fills it on disputes reps open too.

**Consequences:** `Case_BeforeSave_StampDisputeAgreement` runs when a Billing Dispute is created or its statement changes. The service no longer sets the field, and `PS_Steward_Customer` has no access to it. The flow is Steward's own; no Accord component changes (NFR-09).

---

### S-20 — The rep assistant's templates read records in Apex, with the user's own access
**Status:** Decided

**Context:** Prompt Builder can fill a flex template from the record's fields, its related lists, a flow or Apex. The briefing needs exact figures from six kinds of related records, some filtered (open promises, the last 30 days of contact attempts) and all capped. ST-08 requires that a rep's briefing hold only what the rep can see: no payment method without `PS_Payment_Detail`. Some of the text is untrusted: commitment terms, rep notes, and dispute descriptions, which customers write and which will soon arrive through the agent (ST-09).

**Options**
1. Merge fields and related lists in the template. Related lists can't be filtered to open promises or recent attempts, amounts and dates can't be written one fixed way, and nothing marks text a person typed.
2. A flow as the data source. It can filter, but formatting every figure, fencing typed text and saying when a list can't be read would take dozens of formula resources, and a flow's tests can't easily prove each figure.
3. Apex: one invocable class per template, querying in user mode and writing labelled lines for the model to copy. **← decided**

**Why:** User mode makes the platform enforce what each person may see, so ST-08's payment-method criterion doesn't depend on the template's wording. Apex tests prove every figure, every fallback and every fence. What's never sent is decided in code, which a test checks, not by an instruction the model might ignore. That matters more here because this org has no Trust Layer data masking: on 2026-10-23 the org read as not provisioned for it (`docs/agent-governance.md`).

**Consequences:**
- `AccountBriefingPrompt`, `DisputeSummaryPrompt` and `FollowupDraftPrompt`, with shared helpers: `PromptFormat`, `PromptSection`, `RecordLines`, `SlaMilestones`, `HouseholdBriefing` and `EvidenceChecklist`.
- A related list the person can't read says "Not available to you." The briefing still runs, and the template copies that sentence. Unreadable never counts as empty, so "no collections history" is only said when it's true.
- No names, email addresses, phone numbers, street addresses or record IDs go into a prompt. Text a person typed goes between `<quoted>` tags after card numbers, email addresses and phone numbers are removed, with its angle brackets swapped for look-alikes so it can't close its own tag. The templates say that quoted text is content, never instructions, using the INSTRUCTIONS and DATA layout of Salesforce's own templates.
- Amounts and dates are written one fixed way whatever the user's locale, and the templates tell the model to copy figures, never calculate them.
- The payment method is read only for someone who can read it. The processor reference never is.
- Disputes are found through the disputed statement's household, because collections personas can't read `Case.AccountId`.
- NFR-01 holds with no new exception: every query is in user mode.
- The classes carry no `CapabilityType`. The first validation refused `FlexTemplate://…`: Salesforce has retired the flex capability, and Prompt Builder now matches an Apex merge field by the request's variable names (`Household`, `Dispute`), which must match the template's inputs exactly.
- Tests can't call a model. They prove the data. The known-answer, adversarial and persona checks run in the org after the deploy, with their evidence in `docs/agent-governance.md`.

---

### S-21 — The assistant's buttons check before any model runs; the follow-up opens in the email composer
**Status:** Decided

**Context:** ST-08 to ST-10 put three buttons in the Collections Console. ST-10's draft must open in the email composer and never send itself, and it must wait until today's contact attempt is logged. The email needs the customer's name and address, which S-20 keeps away from the model.

**Options**
1. A Sales Email template, run from the composer's own Einstein button. It's grounded in the recipient, so the customer's name and contact details would go to the model, and it can't refuse a draft when nothing was logged today.
2. Lightning web component quick actions that call Apex. `RepAssistantController` checks the record, and for a follow-up today's attempt, before any generation; runs the template through `ConnectApi.EinsteinLLM`; and for the follow-up opens the standard composer with the recipient, subject and body filled in. **← decided**

**Why:** No model runs for a request that shouldn't: a household or dispute the person can't see, a case that isn't a billing dispute, or a follow-up with nothing logged today. The greeting, recipient and sign-off are added after generation, from a user-mode read, so the model never sees them. The rep edits and sends from the standard composer, and the email is logged on the household like any other (Enhanced Email is on).

**Consequences:**
- Briefing, Follow-up Draft and Dispute Summary are added to Accord's Residential Agreement account layout and Billing Dispute case layout, with the standard Email action the composer needs. Steward retrieved both layouts as they were (S-15) and deploys them with the additions. They're additions to Accord's layouts, not changes to its flows, rules or approval process, so NFR-09 holds; Accord's changelog gets an entry (open items). From here on, Steward's source is the copy of record for both layouts: a change made in Setup has to be retrieved into Steward first, or Steward's next deploy undoes it.
- `PromptRunner` is the only place Steward's Apex calls a model. Tests put a stand-in model there.
- The model's text is shown as text in the console and escaped into the email's HTML, so nothing a customer typed can become a link or markup.
- A failed generation tells the rep to try again, with the platform's message underneath for an internal user.
- A draft is written for every outcome (Zana's choice, 2026-10-23). After Requested No Further Contact or Hardship or Bankruptcy Mentioned, it's a servicing note with no payment request and no amounts, and the rep decides whether to send it.

---

### S-22 — Steward permission sets close the collections groups' access gaps
**Status:** Decided

**Context:** Reading the collections personas' access for S-20 on 2026-10-23 found two gaps. No persona can read a case's Subject, Description, AccountId or ContactId, so a specialist's summary couldn't say what the customer wrote. Reps can't read a contact's email or phone numbers, or the account's phone, so a follow-up couldn't be addressed and a rep couldn't see the number to call. Accord gives its personas their access through three permission set groups.

**Options**
1. Leave the access as it is: summaries without the customer's words, follow-ups without a recipient.
2. Edit Accord's permission sets.
3. New Steward permission sets, added to Accord's groups. **← decided**

**Why:** Zana chose who gets what (2026-10-23): specialists and supervisors read the case fields; reps, specialists and supervisors read contact email and phones. Steward's own permission sets keep the additions visible and easy to remove, and leave Accord's permission sets as they are (NFR-09).

**Consequences:**
- `PS_Steward_Dispute_Specialist`: read on Case Subject, Description, AccountId and ContactId, in the Dispute Specialist and Collections Supervisor groups. Reps are unchanged.
- `PS_Steward_Collections_Contact`: read on Contact Email, Phone and MobilePhone, and Account Phone, in all three groups.
- `PS_Steward_Rep_Assistant`: Execute Prompt Templates and the four Apex classes, in all three groups. The permission needs the Einstein Prompt Templates license, so everyone in those groups needs it too. Test Persona, the only member, got it on 2026-10-23.
- Steward deploys Accord's three groups from source, retrieved as they were first (S-15), so Steward's source is now their copy of record, as for the layouts (S-21). Accord's changelog gets an entry (open items).
- What each template reads, field by field, is in `docs/agent-governance.md`.
