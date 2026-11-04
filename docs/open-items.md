# Open Items — Steward

Everything deferred, flagged or half-finished. Updated at the end of every sitting. Nothing gets to live only in a chat log or someone's memory.

**Status key:** ☐ open · ☑ done · ⊘ deliberately not doing

---

## Your list — every phase, as of 2026-11-04

Everything left that needs you, across Steward and Accord, in the order that works best. Each step's clicks are in its phase's section below (or in Accord's open items, where it says so). Claude has done everything else that can be done without you.

**First sitting, in this order (about 1 hour)**
1. **Stripe (Phase 7, steps 1–4, about 20 minutes):** create a Stripe account in test mode and copy its test secret key; put the key into Salesforce on the `Stripe_Test_Key` principal; give yourself **Steward Payment Reconciliation**; schedule the hourly reconciliation with the one line in the Developer Console.
2. **The agent (Phase 6, steps 1–3, about 20 minutes):** create the Lumenfield Service Agent and its user; give the agent user the **Steward Agent** permission set and add it to the **Steward Agent** group; look at the Trust Layer page and note what it offers. Then tell Claude "agent created".
3. **Data 360 (Phase 8, steps 1–2, about 5 minutes and then waiting):** decide whether to turn it on, and if yes, **Get Started** in Data Cloud Setup; check the credit formula ($0.1440 a kWh in the example). Tell Claude "Data 360 ready" when setup finishes.
4. **Two Accord decisions (about 5 minutes, Accord's open items):** the 12 Organization accounts, (a) keep them and fix the description, recommended, or (b) delete their leases and deals; and DEF-11, how sales input reaches a dispute, (a) a Sales Input action, recommended, (b) the case feed, or (c) edit on cases. Answer with the letters.
5. **Accord's UAT-14 email (about 5 minutes):** search your inbox for **Dispute Milestone Violation** around 5 PM CT on Oct 15 and Oct 19, and tell Claude what's there. Then dispute 00001049 can be deleted.

**Before any testing or the walkthrough**
6. **Re-age Accord's data** (Accord's `data/regen/RUNBOOK.md`, about 15 minutes in PowerShell). Bills go overdue again a few weeks after a re-age, so test within a day or two. A re-age deletes every statement and payment, so do it before the test payment, not after.

**Testing (about 30 minutes, `docs/uat-scripts.md`)**
7. **UAT-S15, the timeline (Phase 9):** in the console as a rep, then on the portal as Sandra Barnett.
8. **UAT-S05, a test payment (Phase 7, step 5):** as Sandra Barnett, with the test card 4242 4242 4242 4242.
9. Tell Claude "payments tested" and "timeline checked", with screenshots of anything that looked wrong.

**Housekeeping (about 15 minutes, any time)**
10. **Tags (PowerShell, from `C:\Lumenfield-steward`):** `v0.5` on `6b64a14` now (Phase 5). After UAT-S15 passes, `v0.9` on `5b155ec`; after UAT-S05, `v0.7` on `1c59185`.
11. **Re-clone Accord on your computer** (Accord's open items): rename `C:\Lumenfield-accord` to `C:\Lumenfield-accord-old`, clone again in GitHub Desktop, copy back anything of yours, delete the old folder.
12. **GitHub cleanup (Phase 5, step 6):** delete the branches GitHub marks merged, except `retrieve/2` and `retrieve/3`, and tick **Automatically delete head branches** in Steward's settings.
13. If `docs/release-readiness-winter27.md` is still on your computer, add it to Accord's `docs/` folder.
14. Optional: Accord's last persona check (UAT-06 steps 2–5, `docs/persona-checks.md`), and deleting the unused `Product2.Legacy_Id__c` field.

**The portfolio site**
15. Read the site's Background section once: the roles, dates and numbers come from your résumé.
16. **After you pass the Platform Administrator exam,** and not before: deploy version 5 (unzip `zana-salesforce-portfolio-v5.zip`, drag the folder onto app.netlify.com/drop), then add the link to your résumé, LinkedIn and Trailblazer profile. The site already says certified.

**What Claude does after your steps**
- After "agent created": the Agent Script from `docs/agent-design.md`, publishing and activating it through the pipeline, the portal's chat, the live check that a chat reaches only its own household, the Trust Layer settings, and the test suites in their final form.
- After "payments tested": the payment, its logs and an hourly run checked in the org and recorded, which closes Phase 7.
- After "Data 360 ready": Phase 8, part 2.
- After your Accord answers: the Organization accounts and DEF-11 in Accord, and the escalator step in Accord's data generator (ST-03).
- Phase 10: the suites run, your UAT results recorded, the release notes and `v1.0`, and version 6 of the site with Steward's current figures.

---

## Phase 8 — Data 360 and the production guarantee — part 1, pull request #22

ST-14's rules are built and tested: twelve months of production against the guarantee, and a review with a Draft credit for a shortfall (S-29). The readings come from Data 360, which is licensed in the org but not turned on. On 2026-11-04 its API answered "not currently enabled" for data streams and data spaces, though the Data Cloud license is active and you hold Data Cloud Architect.

**Your steps**
- ☐ 1. **Decide whether to turn on Data 360**, and if yes, turn it on, about 5 minutes plus waiting. It can't be turned off again, and it counts against Developer Edition's Data 360 limits, which is why ST-14 is a Should. Setup → Quick Find `Data Cloud Setup` (it may say Data 360) → **Get Started**. Salesforce sets it up in the background, which can take an hour or more. If the page doesn't offer **Get Started**, take a screenshot for Claude instead.
- ☐ 2. **Check the credit formula**, about 2 minutes: a shortfall is priced at a year of the agreement's monthly payments over its estimated annual kWh. A household paying $120.00 a month with a 10,000 kWh estimate gets $0.1440 a kWh, so 1,000 kWh short is $144.00. Tell Claude "formula OK", or the rule Lumenfield would use instead (S-29).
- ☐ 3. Tell Claude "Data 360 ready" once the setup page says it's done.

**Mine**
- ☑ **Part 1 (pull request #22):** `ProductionGuaranteeService` with its `Readings` source, `Production_Review__c`, `ProductionReviewJob`, `PS_Steward_Production_Review` in the Dispute Specialist and Collections Supervisor groups; 10 tests; S-29; two explainers
- ☐ Merge, deploy, and check in the org: the object and tab, the permission set in both groups
- ☐ **Part 2, after your step 3:**
  - the Ingestion API connector and the monthly production stream, mapped and matched to households
  - the `Production_vs_Guarantee` calculated insight, and the Data 360 readings source that reads it, tested with a query stub
  - a year of invented readings for a few demo households, one of them short
  - the agent's answer to "did my system produce what you guaranteed?" (Get Production Summary), in `PS_Steward_Agent`
  - schedule `ProductionReviewJob` (your step then: one line in the Developer Console, like Phase 7's)
  - UAT-S14

---

## Phase 10 — Testing and release — groundwork

Written ahead, so testing can start as soon as each piece is live.

**Mine**
- ☑ **UAT scripts** (`docs/uat-scripts.md`): one per story, UAT-S01 to UAT-S18, in Accord's format, each with its negative case and, where the agent is involved, its adversarial case. A table says which can run now, which need the agent, and which need Data 360
- ☑ **Agent test suites, drafted** (`tests/agent/`): ten specs, 71 cases. `ST12_Cross_Household` has 28, and one failure blocks activation (ST-12)
- ☐ Turn the suites into test definitions and run them, once the agent exists (`tests/agent/README.md`)
- ☐ Release notes and the `v1.0` tag's summary, once Phases 6 and 10 close: what's in the core release, the evidence for each story, and what's left
- ☐ README and changelog for the release, and the Project docs synced

**Your steps, when the pieces are live**
- ☐ Run the UAT scripts as the table in `docs/uat-scripts.md` allows, with screenshots in `docs/screenshots/uat/`. Tell Claude each result, and Claude records it here and in the changelog
- ☐ Tag each phase once its UAT passes, the way you tagged `v0.4`: `v0.9` on `5b155ec` (pull request #19) after UAT-S15, and `v0.7` on `1c59185` (pull request #20) after UAT-S05. Claude names Phase 6's and Phase 8's commits when they close. Tags are yours to push

---

## Phase 7 — Online payments — deployed 2026-11-04

Customers pay a statement on Stripe's hosted checkout page, in test mode, from the statement's portal page or from a link the agent sends (ST-05). Card details are typed on Stripe's page and never reach Salesforce. Salesforce asks Stripe whether a checkout was paid, when the customer comes back and hourly as a safety net (S-02). Everything is built and tested against a stand-in for Stripe. What's left needs your Stripe account and your hands in Setup.

**Your steps**
- ☐ 1. **Create a Stripe account and copy its test key**, about 10 minutes. The key never goes into a chat, an email or the repository, only into Salesforce in step 2.
  1. Go to `https://dashboard.stripe.com/register` and sign up with your own email. Skip anything about activating payments: test mode works without it.
  2. Make sure you're in **test mode**: the dashboard says Test mode or Sandbox at the top. Real money can't move there.
  3. Optional: Settings → **Business** → **Public details** → set the public business name to `Lumenfield Solar (test)`, so the checkout page shows it.
  4. Open **Developers** → **API keys**. Under **Standard keys**, find the **Secret key** and click **Reveal test key**. It starts with `sk_test_`. Copy it.
- ☐ 2. **Put the key into Salesforce**, about 3 minutes:
  1. Setup → Quick Find `Named Credentials` → **Named Credentials** → the **External Credentials** tab → **Stripe Test**.
  2. Under **Principals**, on the **Stripe_Test_Key** row, open the row's menu (▼) → **Edit**.
  3. Under **Authentication Parameters**, click **Add**. Name: `ApiKey`. Value: paste the key. **Save**.
  4. If anything on the page doesn't match, stop and tell Claude what you see. Don't paste the key anywhere else.
- ☐ 3. **Give yourself the reconciliation permission**, about 2 minutes. The hourly job runs as whoever schedules it, and only users with this permission set can call Stripe. Setup → Quick Find `Users` → **Users** → your name → **Permission Set Assignments** → **Edit Assignments** → move **Steward Payment Reconciliation** to Enabled → **Save**.
- ☐ 4. **Schedule the hourly reconciliation**, about 2 minutes:
  1. Click the gear icon → **Developer Console**. In it: **Debug** → **Open Execute Anonymous Window**.
  2. Paste this one line, then click **Execute**:
     `System.schedule('Steward Payment Reconciliation', '0 15 * * * ?', new PaymentReconciliationJob());`
  3. Setup → Quick Find `Scheduled Jobs` → **Scheduled Jobs**. **Steward Payment Reconciliation** is listed, next run at 15 minutes past the hour.
- ☐ 5. **Pay a statement as Sandra Barnett (UAT-S05)**, about 15 minutes. Follow `docs/uat-scripts.md`, UAT-S05. In short: log in to the portal as Sandra, open her oldest past-due statement, **Pay**, and pay with the test card **4242 4242 4242 4242**, any future expiry date, any CVC and any ZIP code. The statement shows the payment straight away. Take the screenshots the script names.
- ☐ 6. Tell Claude "payments tested", with anything that looked wrong. Claude then checks the payment, the logs and the hourly run in the org, and records the evidence.

Admins already see the integration log, and supervisors get it through their group (pull request #21). You don't need to assign anything for it.

**Mine**
- ☑ **The Stripe integration (S-02):** `StripeClient`, the `Stripe_API` Named Credential and `Stripe_Test` External Credential, `StripeMock` for tests
- ☑ **Paying:** `PaymentCheckoutService`, `CheckoutPayments`, `PaymentRecorder` (S-27), `PaymentReconciliationJob` with the `Payment_Reconciliation_Hours` policy setting (48)
- ☑ **The integration log (S-28):** `Integration_Log__c`, `IntegrationLogger`, `PS_Steward_Integration_Log`
- ☑ **Pay online on the portal:** `portalPayment` on the statement's page, `PortalPaymentsController`, `PortalLinks`, 11 `Steward_Portal_Pay_*` labels
- ☑ **The agent's payment link:** `GetPaymentLinkAction`, in `PS_Steward_Agent` with principal access
- ☑ **Tests:** 53 Apex tests in 10 classes and 15 Jest tests, every one against `StripeMock` or with accessibility checks. Code Analyzer 0 at every severity across the workspace, Prettier and the personal-details check clean
- ☑ **Found on the way** (`CHANGELOG.md`):
  - Apex's `Decimal` has no `movePointLeft` or `movePointRight`.
  - A customer can't query agreements, so tests read household IDs before `System.runAs`.
  - A log row naming a statement that doesn't exist was lost; it's now saved without the link.
  - **Customers can't publish a platform event,** so payments are recorded directly, in system mode, by one class (S-27). Granting them the event would have let them publish payments through the API.
- ☑ **Docs:** S-02 decided; S-27 and S-28; payments in `docs/security-model.md` and `docs/agent-governance.md`; conventions; 13 explainers; ST-05's traceability; UAT-S05
- ☑ **Merged and deployed, 2026-11-04.** Merged at 9:33 AM CT and quick-deployed as Steward CI (`0Afaj00000qNPJ8CAO`, of validation `0Afaj00000qNh6MCAS`: 390 components, 280 of 280 tests). The pipeline republished the portal. In the org afterwards:
  - The `Stripe_Test` External Credential and `Stripe_API` Named Credential are in.
  - `PS_Steward_Customer`, `PS_Steward_Agent` and `PS_Steward_Payment_Reconciliation` each reach the `Stripe_Test_Key` principal, and nothing else does.
  - The payment classes are in, the integration log is empty, and `Payment_Reconciliation_Hours` reads 48.
- ☐ After your steps 1–6: check the payment, its logs and an hourly run in the org, and record the evidence here and in the changelog

**Known and accepted**
- ⊘ **Two open checkouts for one statement can both be paid** within the hour they stay open. Both are real payments, so both are recorded; the second shows as a credit, and a rep refunds it in Stripe. A production build would expire a statement's other open sessions when one is paid (S-02).
- ⊘ **No webhook.** A customer who pays and never comes back waits up to an hour for the payment to show (S-02).

---

## Phase 9 — Customer timeline — deployed 2026-11-03

Built ahead of Phases 7 and 8. One household's history on one timeline (ST-15): statements, payments, promises to pay, billing disputes, credits and commitments, newest first, filtered by kind. Reps get it as the first tab on the console's account page. Customers get their own household's on the portal's My Account page.

**Your steps**
- ☑ 1. Make the new account page the console's default. Claude did this through the API after the deploy, at about 7:51 PM CT on 2026-11-03, by setting the Collections Console's account page assignment (S-26). Nothing for you to do.
- ☐ 2. **Look at it yourself (UAT-S15)**, about 10 minutes:
  1. In the Collections Console, open any household account, such as Sandra Barnett's. The first tab, **History**, shows the timeline. Untick **Payments**, then tick it again. Scroll to the bottom, or use **Show more** if there is one. Click a statement's heading: it opens in a subtab.
  2. Use only the keyboard for a minute: Tab reaches each filter box and each link, Space ticks a box, and Show more moves you to the first new event.
  3. Log in to the portal as Sandra Barnett, the same way as in Phase 4. **My Account** shows **Account history** below the figures: statements, payments, the promise and the dispute, and no credits or commitments.
  4. Tell Claude anything that looks wrong, with a screenshot.

**Mine**
- ☑ **The server side (S-25):** `CustomerTimelineController`, `TimelineReader`, `TimelineKind`, `TimelineCursor`. Every read is in user mode and names only readable fields. Pages hold 20 events, and each kind keeps its own count between pages
- ☑ **The component:** `customerTimeline`, with the filter, Show more plus loading on scroll, focus moved after Show more, loading, empty, no-access and error states, and 39 `Steward_Timeline_*` labels
- ☑ **Where it appears (S-26):** `Steward_Account_Record_Page` (History, Related and Details tabs, activity alongside) and the portal's My Account page
- ☑ **Access:** `PS_Steward_Timeline` in the three collections groups; the controller in `PS_Steward_Customer`
- ☑ **Tests:** `CustomerTimelineControllerTest` (10), `TimelineCursorTest` (3), 17 Jest tests and one more for My Account, each state with an accessibility check. Code Analyzer 0 at every severity, Prettier and the personal-details check clean
- ☑ **Found and fixed on the way** (`CHANGELOG.md`):
  - Steward's tests had stopped compiling in the org when Accord's adjustments became auto-numbered (pull request #18's guard couldn't help).
  - A `Date` passes `instanceof Datetime` in Apex, which had moved dates a day.
- ☑ **Docs:** decisions S-25 and S-26; five explainers; `docs/security-model.md`; conventions; traceability; changelog
- ☑ **Merged and deployed, 2026-11-03.** Merged at 7:47 PM CT and quick-deployed as Steward CI (`0Afaj00000qKENRCA4`, of validation `0Afaj00000qKCqHCAW`: 339 components, 227 of 227 tests). The pipeline republished the portal. In the org afterwards:
  - The three collections permission set groups include `PS_Steward_Timeline` and show Updated.
  - `Steward_Account_Record_Page` is the Collections Console's account page.

---

## Phase 6 — Service agent — in progress

Pull request #17 built everything the agent will run, and the access it runs with, before the agent itself exists. That covers the nine actions, how a chat finds its household, the shared plumbing, the agent user's permission set and sharing, the supervisor's access to the log, and the docs. Next come the agent itself, its chat on the portal and its Trust Layer settings. Those start with you in Setup.

**Your steps**
- ☐ 1. **Create the agent and its user**, about 10 minutes. If a screen doesn't match these steps, stop and tell Claude what you see. Agentforce Builder changes often.
  1. In Salesforce: the gear icon → **Setup** → type `Agentforce Agents` in Quick Find → **Agentforce Agents** → **New Agent**.
  2. Choose the template for customers, **Agentforce Service Agent**.
  3. Name it `Lumenfield Service Agent`, with the API name `Lumenfield_Service_Agent` (conventions).
  4. When it asks about the agent user, choose to **create a new agent user**. If it lets you name the user, use `Steward Agent`.
  5. Add no topics or actions, and don't activate it. Claude writes those in its Agent Script.
- ☐ 2. **Give the agent user its access**, about 3 minutes:
  1. Setup → Quick Find `Users` → **Users** → open the new agent user.
  2. **Permission Set Assignments** → **Edit Assignments** → move **Steward Agent** to Enabled → **Save**.
  3. Setup → Quick Find `Public Groups` → **Public Groups** → **Steward Agent** → **Edit**. Under **Search**, choose **Users**, add the agent user, and click **Save**. If the agent user isn't in the list, tell Claude, who can add it through the API.
- ☐ 3. **Look at the Trust Layer page for Claude**, about 5 minutes. Setup → Quick Find `Einstein Trust Layer`. Note which of these the page offers, and whether each can be turned on: Prompt Security (the master switch), data masking, prompt injection detection, toxicity detection, and audit and feedback (Data 360). Don't change anything yet. The recommendations are at the end of `docs/agent-governance.md`'s settings section.
- ☐ 4. Then tell Claude "agent created". In the next sitting, Claude:
  - retrieves the agent into this repository
  - writes its Agent Script: the subagents and their instructions, each action's session input bound to `$Context.RoutableId`, and a confirmation before every write (GR-05)
  - builds the Enhanced Chat channel and the portal's chat through the pipeline
  - walks you through the live check: a chat from the logged-in portal answers for that customer's household, and an anonymous one doesn't (S-23)

**Mine**
- ☑ **Nine agent actions** (`<Verb><Noun>Action`), one per service call. Each takes the messaging session's ID, never an account, logs every request, and has its own test class covering:
  - its own household
  - another household's records, where it takes an ID
  - a chat with no customer behind it
  - a failure, which gives a reference instead of the error
- ☑ **How a chat finds its household (S-07, S-23):** `AgentSession` follows the platform's own link, `MessagingEndUser.AuthenticatedEndUserId`, to the verified portal user and that user's account. It serves only the portal's web chat, only an open session, and only an active customer user. Tests can't open a chat, so `AgentTestSessions` stands in
- ☑ **Shared plumbing:** `AgentActions.Calls`. The first version passed every test but brought 22 Code Analyzer findings into a codebase that had none. Rebuilt on `Calls`, it's back to 0 at every severity. Prettier and the personal-details check are clean
- ☑ **Access (S-01):** `PS_Steward_Agent`, the Steward Agent group, and sharing rules `Households_to_Steward_Agent` and `Agreements_to_Steward_Agent`. `PS_Steward_Supervisor` is in the Collections Supervisor group (ST-11). Written up in `docs/security-model.md`
- ☑ **`AgentAccessTest`** runs the nine actions as an Einstein Agent User with only that access. Writing it found four things the plan had missed:
  - The statement explanation reads the agreement's start date, so the agent needs read on it.
  - A promise to pay is a master-detail child of its account, so adding one needs edit access to the account. The sharing rule gives Edit, and the permission set keeps every account field read only.
  - Opening a dispute reads the household's primary contact and names it on the case. Both are lookups to Contact, and a lookup to an object the user can't read is hidden. So the agent gets read on the Contact object, though no contact field, as customers do.
  - A check-only deployment doesn't apply the sharing rules it brings, so the test grants the group the same access by hand. The rules themselves are checked in the org after the merge.
- ☑ **S-14's open question:** the agent user can't set a case's account, so the dispute insert stays in system mode (`AgentAccessTest`)
- ☑ **Graph Engine** with the actions as entry points: the same two S-08 findings as Phase 4, and nothing from the agent's paths (`docs/pipeline.md`)
- ☑ **Docs:**
  - decisions S-23 and S-24, and S-01 confirmed
  - `docs/security-model.md`
  - the actions' answers and the Trust Layer recommendations in `docs/agent-governance.md`
  - 12 explainers
  - traceability, pipeline and this file
- ☑ **#17 merged and checked in the org (2026-11-03).** Merged at 2:29 PM CT and quick-deployed (`0Afaj00000qIxoTCAS`, of validation `0Afaj00000qIvl3CAC`: 214 of 214 tests). In the org:
  - The household rule shares all 88 Residential Agreement accounts with the Steward Agent group (Edit, cases Read), and none of the 12 Organization accounts.
  - The agreement rule shares all 100 agreements, read only. That includes the 12 on Organization accounts, which the agent never reaches.
  - Accord's own account rule still shares the 34 accounts in collections with Collections Team.
  - `PS_Steward_Supervisor` is in the supervisor group, which recalculated (status Updated).
- ☑ **Ready for Accord's adjustment numbers** (pull request #18): Steward's test data named an adjustment only while the name was still plain text. That turned out not to be enough: Apex checks the field can be written when the class compiles, so Accord's switch stopped Steward's tests compiling. Fixed in pull request #19 (Phase 9)
- ☑ **Done without the agent (pull request #21, deployed 2026-11-04 at 9:46 AM CT, quick deploy `0Afaj00000qNr8vCAC`; checked in the org):**
  - **The Steward Agent dashboard (ST-11):** five reports and a dashboard that runs as the viewer, shared with the Collections Supervisor role.
  - **Supervisors can see the log now.** `PS_Steward_Supervisor` had read but not View All, and the log's records belong to the agent user and customers, so a supervisor saw none. Found while building the dashboard.
  - **The agent's design** (`docs/agent-design.md`): every subagent's instructions and actions, the confirmation step, the welcome message, and the reason code passed into the handoff (ST-07). Writing the Agent Script becomes a conversion.
  - **The agent test suites, drafted:** ten specs, 71 cases, in `tests/agent/`.
- ☐ **Next sitting, after your steps 1–3:**
  - the Agent Script, from `docs/agent-design.md`, in the retrieved bundle
  - publish and activate in `deploy.yml` (S-10)
  - the Enhanced Chat channel, deployment and portal chat
  - the live S-23 check
  - the Trust Layer settings
  - the agent test suites in their final form, once it's clear how a suite gets a logged-in customer (`docs/agent-design.md`, open questions)
- ⊘ **Two escalator statements on a demo household (ST-03), moved to Accord.** A re-age deletes and rebuilds every statement (Accord's `data/regen/RUNBOOK.md`), so statements added by hand would vanish at the next one. The escalator step belongs in Accord's generator, as an Accord change with its own changelog entry. Until then ST-03's escalator is shown by `StatementExplanationServiceTest` ($120.00, then $123.48)

---

## Phase 5 — Rep assistant — closed 2026-10-26

Pull request #9 built it: the three prompt templates and the Apex behind them, the three buttons, and the permission sets. #10 activated the templates and added the docs. #11 fixed what the org checks found and recorded their evidence. #13 records what the hand check found and finishes Accord's DEF-07 on the account layout. #14 lets a supervisor change Collection Hold Until from that layout. #15 records #14's deploy, and #16 closes the phase. Claude pushes each one, merges it once its final commit validates, and checks the deploy.

**Your steps**
- ☑ 1. Three decisions (2026-10-23): specialists and supervisors read a case's subject, description, account and contact; reps, specialists and supervisors read contact email and phone numbers; a follow-up is drafted for every outcome (S-21, S-22)
- ☑ 2. Hand check as Test Persona (steps below). Steps 1–4 on 2026-10-24 (login at 8:10 PM CT, in the audit trail); step 5 then found Accord's DEF-08, fixed the same night. **Steps 5–8 on 2026-10-26:** login 1:51 PM CT, logout 1:54 PM CT (audit trail); the Left Voicemail attempt with the note "Hand check" on Sandra Barnett Household at 1:53 PM CT; follow-up draft and dispute summary as written, by your report, and no email sent (none from Test Persona in the org)
- ☑ 3. Accord's changelog: the entry below is in Accord's `CHANGELOG.md` v1.0.2, with a second entry for pull request #13 (2026-10-25)
- ☐ 4. `v0.5` tag on `6b64a14`, the merge of pull request #16, which closes Phase 5. From `C:\Lumenfield-steward` in PowerShell: `git pull`, then `git tag v0.5 6b64a14`, then `git push https://Zana-yocum@github.com/zana-yocum/Lumenfield-steward.git v0.5`
- ☑ 5. **GitHub email privacy on (2026-10-25).** Checked: pull request #13's merge commit carries your noreply address. The 19 earlier commits on `main` still carry your private address (the 12 pull-request merges and 7 commits pushed from your computer). Removing those means rewriting `main` and recreating the v0.1–v0.4 tags, which only you can push: say so if you want it, and Claude prepares it. If you push from your computer again, first run once in PowerShell: `git config --global user.email "333481738+zana-yocum@users.noreply.github.com"`
- ☐ 6. Optional cleanup on GitHub, about 5 minutes. Claude can't delete branches.
  - **Branches** (the repository's **Code** tab → **Branches**): every branch GitHub marks merged can be deleted with the trash icon, which since 2026-11-04 includes `fix/adjustment-names`, `phase-6/agent-actions`, `phase-7/payments` and `phase-9/customer-timeline`, and pull requests #21 and #22's branches once they merge. The 14 from earlier: `docs/open-items-tags`, `docs/phase-4-close`, `docs/phase-4-evidence`, `docs/phase-4-walkthrough`, `docs/phase-5-close-out`, `docs/phase-5-closed`, `docs/phase-5-closed-out`, `docs/phase-5-status`, `feature/phase-4a-digital-experiences`, `feature/phase-4b-portal`, `feature/phase-5-rep-assistant`, `fix/phase-5-hand-check-findings`, `fix/phase-5-match-flag`, `fix/supervisor-hold-override`. So can `tools/accord-restore`, `retrieve/5` and `retrieve/6`, which only restored Accord's repository. **Keep `retrieve/2` and `retrieve/3`:** these docs cite them as the record of what was retrieved
  - **Settings** → **General** → **Pull Requests** → tick **Automatically delete head branches**, so merged branches go away on their own. Accord's repository already has it

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
  - ☑ Payment method in a rep's briefing: none, as expected, since Test Persona can't read it (below). Confirmed in the hand check, step 3 (2026-10-24)
- ☑ Found by the checks: 00001035's summary called an unflagged commitment a possible match. Pull request #11 marks every other commitment as not flagged: validated (`0Afaj00000ovn8rCAA`, 159 of 159 tests), merged and deployed (`0Afaj00000ovl74CAA`). Rerun: the commitment is now described as not flagged
- ☑ Test records removed: COM-00034 deleted; dispute 00001054 closed, and Accord set STMT-00640 back to Past Due. The Promise Made attempt and PTP-00142 stay on Andre Radcliff's household as ordinary activity; the attempt's notes say it was an org check
  - ☑ Persona access (2026-10-23): Test Persona can read every field the templates read except the payment method, the processor reference, and a case's description, subject, account and contact, as S-22 intends
- ☑ **Hand check finding, 2026-10-24: Accord's DEF-08.** Test Persona saw Briefing and Follow-up Draft but not Log Contact Attempt. The action launches Accord's screen flow `Account_Screen_LogContactAttempt`, and a user needs the Run Flows permission or access to that flow. Minimum Access and Accord's permission sets gave neither. Fixed in the org the same night, least privilege, in Accord's components: flow version 3 restricts access to enabled permission sets, and `PS_Collections_Core` grants that one flow. Checked through the API: the three collections groups recalculated with the access; Sales Rep has none. Recorded in Accord's CHANGELOG v1.0.2 and results doc. Steward's Follow-up Draft needs a logged attempt, so it had been unusable for real reps
- ☑ **Accord's DEF-09, found 2026-10-24 and fixed 2026-10-25 in Accord's components:** the Minimum Access profile granted access to 74 Accord fields, 58 editable. Each persona's fields now come from its permission sets, and the profile grants none. Checked in the org: each group's field permissions match the plan exactly (Collections Rep 56 Accord fields, 4 editable; Dispute Specialist 63, 17; Collections Supervisor 63, 20; Sales Rep 29, 12). Test Persona still reads every field Steward's templates read. In this repository: `PSG_Collections_Supervisor` includes Accord's new `PS_Collections_Overrides`, in pull request #13
- ☑ Pull request #13 merged 2026-10-25 and quick-deployed (`0Afaj00000p7b8jCAA`, 259 components). Checked in the org: the Commitments related list on the Residential Agreement layout (type, value, status), which finishes Accord's DEF-07; `PS_Collections_Overrides` in the supervisor group; and the three groups' corrected descriptions, which no longer describe the Promise to Pay delete Accord's OBS-01 removed. Also in #13: the Phase 4 portal screenshots in `docs/screenshots/phase-4/`, moved from Accord's repository
- ☑ Pull request #14 merged 2026-10-25 and quick-deployed (`0Afaj00000p7cPlCAI`, 259 components): Collection Hold Until editable on the Residential Agreement layout. Accord's DEF-09 gives supervisors edit on it, but the layout showed it read-only, so the override couldn't be used from the page. Checked in the org: the layout field is Edit; the Collections Supervisor group can edit the field, the rep and specialist groups can only read it, and the Sales Rep group can't see it; Test Persona still reads it as read-only. Accord's changelog records it (Accord pull request #2)
- ☑ **Accord's DEF-10, found 2026-10-25 and fixed 2026-10-26 in Accord's sharing rules:** every collections rep could read every customer account through a closed-deal rule. The rep assistant reads as the user, so a rep now reaches the 34 accounts in collections, with their deals and commitments, and 6 current accounts with a billing dispute, read-only. Nothing in this repository changed; the 159 Apex tests passed after each step
- ⊘ **Known limit from that fix:** on those six current accounts a rep can read the household but not its deal, so a briefing or dispute summary there says "None." for commitments that exist. Saying "Not available to you." would need a check outside the person's own access, which S-20 rules out. Reps don't work current accounts, and dispute specialists read every closed deal (`docs/agent-governance.md`)
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
- ☑ How the logged-in customer's identity reaches the agent (S-07): `MessagingEndUser.AuthenticatedEndUserId`, read in system mode by `AgentSession` (S-23). ☐ The live check with a real chat is in Phase 6's steps
- ☐ Confirm whether the chat transcript can mask a typed card number (ST-05)
- ☐ Decide the Trust Layer settings and record them in `docs/agent-governance.md` (ST-17)
- ☐ Add agent publish and activate to `deploy.yml` (S-10), once the agent's script is in the repo
- ☑ Invocable actions, one per service call (`<Verb><Noun>Action`): each takes the verified account from the session, calls the service, writes one log record through `AgentActionLogger`, and returns the typed result. Nine, in pull request #17
- ☑ `Agent_Action_Log__c.Conversation_Id__c` holds the messaging session's ID; a supervisor opens the conversation at `/lightning/r/MessagingSession/<ID>/view` (S-24)
- ☑ `PS_Steward_Agent`, from what the Phase 3 services read and write in user mode, now in `docs/security-model.md`. Two changes from this plan: the agreement's `StartDate` is read too, and nothing is needed on `Case.Service_Contract__c`, which a flow stamps (S-19). The plan was:
  - **Account:** read `Account_Status__c`, `Broken_Promises_90d__c`, `Current_Balance__c`, `Past_Due_Balance__c`, `Oldest_Past_Due_Date__c`, `Primary_Contact__c`. Residential Agreement accounts reached through a criteria-based sharing rule (S-01)
  - **Billing Statement:** read the statement fields, including `Service_Contract__c`
  - **Service Contract:** read `Escalator_Rate__c`, `First_Due_Date__c`, `StartDate`
  - **Lease Payment:** read name, date and amount only. No method, no processor reference
  - **Adjustment:** read `Type__c`, `Amount__c`, `Posted_Date__c`, `Status__c`, `Billing_Statement__c`
  - **Promise to Pay:** read and create `Promise_Date__c`, `Promise_Amount__c`, `Status__c`; read `Grace_Ends__c`
  - **Case:** create, plus create on `Disputed_Statement__c`, `Service_Contract__c`, `Dispute_Reason__c`, Origin, Subject, Description and Contact. Without them `DisputeIntakeService` answers `ACCESS_DENIED`. Also read access to Billing Dispute cases through sharing, so the agent can read back the case number once the case is in the Dispute Specialists queue
  - **Nothing on** `Commitment__c`, `Opportunity` or `Agent_Action_Log__c`: the services handle those (S-08, S-09)
- ☑ S-14 with the agent user, two checks. First: it can't set `Case.AccountId` (`AgentAccessTest`), so the exception stays. Second: Phase 4 proved the field-level refusal with a customer user (`PortalControllersTest`), through the same service the agent calls. The original note: First, what its create access to `Case.AccountId` really is: if it can set the field, the dispute insert moves to user mode and the exception goes. Second, a dispute from a user who can create cases but not one of the dispute fields comes back `ACCESS_DENIED` naming that field, with nothing saved. Phase 3 could only test a user with no Case access (no Salesforce license is free), and the third validation shows the field-level lines never ran
- ☑ `PS_Steward_Supervisor`: read on `Agent_Action_Log__c`, for the Steward Agent dashboard (ST-11), in the Collections Supervisor group. Reps get nothing on it
- ☑ When a service returns `HANDOFF`, the reason code goes into the handoff summary, so the rep knows which limit was hit (ST-07). `RecordHandoffAction` takes the code and logs it; the design has the script keep the last reason code and pass it on (`docs/agent-design.md`). ☐ Built into the Agent Script with the rest
- ☑ Run Code Analyzer's Graph Engine rules once the actions exist (2026-11-03): the same two S-08 findings, nothing from the agent's paths
- → Two statements showing an escalator step on a demo household: moved to Accord's generator (Phase 6, above), since a re-age rebuilds every statement

**Phase 7 — Payments**
- → Moved to Phase 7's steps 1 and 2 above: a free Stripe account in test mode, with the test secret key in the `Stripe_Test` External Credential and nowhere else
- ☐ Confirm in the org that a customer's callout works with the principal access its permission set grants. Tests mock Stripe, so only UAT-S05 can show it

---

## Risks to watch

- **Steward's source is now the copy of record for two Accord layouts and three Accord groups** (S-21, S-22). A change made to them in Setup is undone by Steward's next deploy unless it's retrieved into Steward first (S-15). That includes Accord's unfinished DEF-07, the Commitments related list on the Residential Agreement layout, which now has to be added in Steward's source.
- **Einstein usage is capped in Developer Edition**, and agent test runs use it. Keep test suites focused and run the full set at release.
- **Data 360 usage is capped** too, which is why ST-14 is a Should.
- **Five customer licenses.** The plan uses three test households, which leaves room for a fourth if a test needs one.
- **No spare Salesforce licenses** now that Steward CI has the fourth. A second persona user would mean switching Test Persona between roles, as Accord did. Apex tests use a Salesforce Platform user instead.
- **Apex test time.** Every pull request now runs 83 tests in the org, and five of them build 200 households through Accord's flows. Phase 3's three runs took 227, 114 and 149 seconds of test time. In the third, the slowest test, opening 200 disputes, took 32 seconds. If a run nears the CPU limit, the bulk tests are where to look.
- **Steward's source carries Accord's account sharing rule** `Delinquent_Accounts_to_Collections`, unchanged, in the same file as the agent's rule, so deploying the file can't drop it. Like the layouts and groups, a change to it in Setup is undone by Steward's next deploy unless it's retrieved first.
- **Nobody but supervisors reads the action log**, and they do once pull request #17 deploys `PS_Steward_Supervisor`. The admin isn't in that group and has no access to the log's fields, so reading the log as the admin needs `PS_Steward_Supervisor` assigned too.
- ☑ **Accord's DEF-07 finished by pull request #13:** the Commitments related list is on the Residential Agreement layout, which this repository maintains. Steward depends only on the `Account__c` field.
