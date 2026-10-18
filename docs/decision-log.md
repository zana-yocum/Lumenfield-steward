# Decision Log — Steward

The decisions that shape Steward, the options considered, and why one was chosen. Same format as Accord's D-01 to D-10.

**Status:** **Decided**, or **Proposed**: a starting position that's confirmed or changed, with evidence from the org, in the phase shown.

| ID | Decision | Status |
|---|---|---|
| S-01 | The service agent runs as its own least-privilege user | Proposed · Phase 6 |
| S-02 | Salesforce asks the payment provider; the provider never calls Salesforce | Proposed · Phase 7 |
| S-03 | Apex for agent actions; Accord's flows keep the policy | Decided |
| S-04 | Customer Community licenses with sharing sets | Proposed · Phase 4 |
| S-05 | The pipeline validates against the org; no scratch orgs | Decided |
| S-06 | What the agent may never do | Decided |
| S-07 | The model never chooses whose data to read | Decided · mechanism confirmed in Phase 6 |
| S-08 | Customers see commitments through a scoped read service | Proposed · built in Phase 3, confirmed in Phase 4 |
| S-09 | Agent outcomes are logged to a custom object | Decided |
| S-10 | The agent's definition lives in Git and ships through the pipeline | Decided |
| S-11 | The portal is an LWR site | Proposed · Phase 4 |
| S-12 | The pipeline signs in as its own user, with a certificate | Decided |
| S-13 | Pull requests are required for anything that deploys | Decided |
| S-14 | Dispute cases are saved in system mode, with the caller's create access applied to every other field | Decided |
| S-15 | Configuration built outside source is retrieved by the pipeline | Decided |

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
**Status:** Proposed · confirm in Phase 4

**Context:** Customers must see only their own household. The org has five Customer Community and five Customer Community Plus licenses.

**Options**
1. **Customer Community:** no roles; record access through sharing sets matched on the user's account. **← starting position**
2. **Customer Community Plus:** adds roles, sharing rules and reports.

**Why:** "The household" maps exactly onto a sharing set (the record's account is the user's account), and the master-detail records follow the account. Plus adds role-based sharing that nothing here needs.

**Consequences:** Two limits shape the design. Customer licenses can't be given opportunity access (S-08), and each customer user can reach at most 10 custom objects; the portal needs three (Billing Statement, Lease Payment, Promise to Pay). Account owners must have a role before a contact can become a customer user, which is checked in Phase 4.

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
**Status:** Proposed · confirm in Phase 4

**Context:** Commitments are detail records of the opportunity, so seeing one requires access to its opportunity. Customer licenses can't be given opportunity access, and customers shouldn't see the deal record anyway.

**Options**
1. Change Commitment's relationship to the opportunity so commitments can be shared on their own. That rebuilds Accord's data model (NFR-09).
2. Copy commitments into an object customers can see: two copies that can drift.
3. A read service that runs in system mode, finds commitments by `Account__c` for the verified household only, and returns five fields. **← starting position**

**Why:** Option 3 keeps one source of truth and exposes the minimum. Accord's DEF-07 lookup (`Commitment__c.Account__c`) makes the household filter a single field.

**Consequences:** This is one of three named exceptions to user mode (NFR-01), with S-09 and S-14. It lives in an inner class with a comment citing S-08, and tests prove that a customer, the agent, and a portal call carrying another household's ID each get only their own household's commitments.

**Built in Phase 3** as `CommitmentReadService`. The user-mode household check runs first, and the elevated read is a single query in an inner `Elevated` class that selects only the five customer fields. `CommitmentReadServiceTest` runs as a user with no access to commitments or opportunities: given read access to one household, the user gets that household's commitments through the service, while the user's own query on `Commitment__c` is blocked and a second household stays not found. All seven of its tests passed in the org on 2026-10-18 (validation `0Afaj00000oBwtVCAS`). Phase 4 confirms in the org that customer licenses can't be given opportunity access, which is what makes the service necessary.

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
**Status:** Proposed · confirm in Phase 4

**Context:** Experience Cloud sites are built on either Lightning Web Runtime (LWR) or the older Aura framework.

**Options**
1. **Aura** (Customer Service template): more ready-made components.
2. **LWR** (Build Your Own): faster pages built from Lightning web components, and the direction of Salesforce's newer Experience Cloud features. **← starting position**

**Why:** Steward's portal pages are mostly its own components (ST-01, ST-02, ST-15), so Aura's ready-made components matter less than LWR's speed.

**Consequences:** Phase 4 confirms everything the portal needs, including the Enhanced Chat deployment, works in an LWR site before building it.

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

**Consequences:** `DisputeIntakeService` refuses with `ACCESS_DENIED`, and saves nothing, when the caller can't create cases or set any field other than the account. A test proves it for a user with no Case access, and it passed in the org on 2026-10-18. The field-level refusal has no test yet: it needs a user who can create cases but not one of the dispute fields, and no Salesforce license is free to make one. Phase 6 checks it with the agent user. This is the third named exception to user mode (NFR-01), after S-08 and S-09. It's one statement with a comment citing S-14. The agent user still needs Case create and access to the dispute fields, and read access through sharing to see the case number once the case is in the queue (Phase 6). Phase 6 also checks what the agent user's create access to `Case.AccountId` really is. If the agent can set it, or edit on it is granted for another reason, the insert can move to user mode and this exception can be removed.

---

### S-15 — Configuration built outside source is retrieved by the pipeline
**Status:** Decided

**Context:** Some configuration doesn't start in source. The portal site is created from Salesforce's Build Your Own (LWR) template, which generates its pages, theme and settings, and a later change might be made in Experience Builder or Setup. ST-13 requires all of it in the repo the same day, so the repo stays the record of what's in the org.

**Options**
1. Retrieve on a laptop with the Salesforce CLI and commit by hand, as Accord did.
2. A workflow that retrieves as Steward CI and pushes the result to a branch of its own. **← decided**

**Why:** Option 2 uses the same identity and tool versions as the deploys, leaves a run log for every retrieve, and needs nothing installed or signed in on anyone's computer. Option 1 depends on whoever runs it having the CLI signed in to the right org.

**Consequences:** `retrieve.yml` runs by hand, on the branch that holds the manifest, and pushes `retrieve/<run number>`. It can't change `main`: the ruleset doesn't let it. GitHub doesn't start workflows from pushes made with its own token, so a retrieved branch doesn't validate by itself. Its files reach `main` in an ordinary pull request, which does.
