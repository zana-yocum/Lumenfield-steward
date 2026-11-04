# Explainers

One page per Apex class, Lightning web component, prompt template and agent subagent (NFR-04). Written so the component can be walked through in an interview without opening the code. Name each file after the component: `PaymentArrangementService.md`.

## Index

**Apex services (Phase 3)**

| Component | One line | Stories |
|---|---|---|
| [AccountSnapshotService](AccountSnapshotService.md) | Where a household stands: balances, statements, payments, disputes, open promise | ST-01 |
| [CommitmentReadService](CommitmentReadService.md) | What was promised at signing, five fields, through Steward's one elevated read | ST-02 · S-08 |
| [StatementExplanationService](StatementExplanationService.md) | Why a bill changed, from the household's own records | ST-03 |
| [AmountDueComparison](AmountDueComparison.md) | The escalator rule: no change, escalator, or unexplained | ST-03 |
| [PaymentArrangementService](PaymentArrangementService.md) | A promise to pay inside policy, rolled back if Accord would need approval | ST-04 |
| [ArrangementEligibility](ArrangementEligibility.md) | The self-service rules for a promise, in order | ST-04 |
| [DisputeIntakeService](DisputeIntakeService.md) | A Billing Dispute case on the household's statement, with its evidence list | ST-06 · S-14 |
| [DisputeEvidenceCatalog](DisputeEvidenceCatalog.md) | The eight dispute reasons and the evidence each needs | ST-06 |
| [AgentActionLogger](AgentActionLogger.md) | One log record per agent action, declined requests included | ST-11 · S-09 |

**The customer portal (Phase 4): Apex**

| Component | One line | Stories |
|---|---|---|
| [PortalAccountController](PortalAccountController.md) | My account, Statements and one statement, for the logged-in household | ST-01 · ST-12 |
| [PortalCommitmentsController](PortalCommitmentsController.md) | What we promised you, through the S-08 read service | ST-02 · S-08 |
| [PortalDisputesController](PortalDisputesController.md) | The household's disputes, the dispute form, and opening a dispute | ST-06 · S-14 |
| [DisputeStatusService](DisputeStatusService.md) | A household's billing disputes and one dispute's evidence list | ST-06 · S-16 |
| [PortalHousehold](PortalHousehold.md) | The logged-in customer's household, from their user, never from the page | ST-12 · S-07 |
| [PortalFailure](PortalFailure.md) | A failure's details to the log, a reference to the customer | NFR-07 |
| [PortalTestData](PortalTestData.md) | Customer users and the cases they must never see, for the tests | S-04 · S-18 |

**The customer portal (Phase 4): Lightning web components**

| Component | One line | Stories |
|---|---|---|
| [portalHeader](portalHeader.md) | The links on every page, with the current one marked | NFR-05 |
| [portalMyAccount](portalMyAccount.md) | Balance, past due, oldest unpaid statement, next payment, arrangement | ST-01 |
| [portalStatements](portalStatements.md) | Every statement, newest first | ST-01 |
| [portalStatementCard](portalStatementCard.md) | One statement's amounts, status and payments | ST-01 |
| [portalStatementDetail](portalStatementDetail.md) | A statement's own page, from the ID in the address | ST-01 · ST-12 |
| [portalCommitments](portalCommitments.md) | What was promised at signing, terms as recorded | ST-02 |
| [portalDisputes](portalDisputes.md) | The dispute form and the household's disputes | ST-06 |
| [portalDisputeForm](portalDisputeForm.md) | Opens a dispute and shows what to send | ST-06 · NFR-07 |
| [portalDisputeDetail](portalDisputeDetail.md) | A dispute's own page, with its evidence list and upload area | ST-06 · ST-12 |
| [portalShared](portalShared.md) | Pages, labels, outcome codes and the words for problems | NFR-07 · ST-18 |
| [portalStyles](portalStyles.md) | The shared stylesheet, every value from an SLDS styling hook | NFR-05 |

**The rep assistant (Phase 5): Apex**

| Component | One line | Stories |
|---|---|---|
| [RepAssistantController](RepAssistantController.md) | The three buttons' server side: checks first, then the template; the follow-up as an email | ST-08 · ST-09 · ST-10 · S-21 |
| [AccountBriefingPrompt](AccountBriefingPrompt.md) | The briefing's data, read with the rep's own access | ST-08 · S-20 |
| [DisputeSummaryPrompt](DisputeSummaryPrompt.md) | The dispute summary's data, the customer's words fenced as quoted text | ST-09 · S-20 |
| [FollowupDraftPrompt](FollowupDraftPrompt.md) | Today's call outcome and promise, for the follow-up | ST-10 · S-20 |
| [PromptRunner](PromptRunner.md) | The only place Steward's Apex calls a model | S-21 |
| [PromptFormat](PromptFormat.md) | Figures one fixed way, and typed text fenced | S-20 |
| [PromptSection](PromptSection.md) | A part of a prompt: lines, "None", or "Not available to you." | S-20 |
| [RecordLines](RecordLines.md) | One line per kind of record, the same in every prompt | ST-08 · ST-09 |
| [HouseholdBriefing](HouseholdBriefing.md) | The briefing's shape and its no-history rule | ST-08 |
| [SlaMilestones](SlaMilestones.md) | A dispute's next SLA milestone, missed or not | ST-08 · ST-09 |
| [EvidenceChecklist](EvidenceChecklist.md) | The evidence a dispute's reason needs, against the files attached | ST-09 |

**The rep assistant (Phase 5): Lightning web components and prompt templates**

| Component | One line | Stories |
|---|---|---|
| [repBriefing](repBriefing.md) | The Briefing button on a household | ST-08 |
| [repDisputeSummary](repDisputeSummary.md) | The Dispute Summary button on a billing dispute | ST-09 |
| [repFollowupDraft](repFollowupDraft.md) | The Follow-up Draft button: opens the email composer | ST-10 |
| [repGeneratedText](repGeneratedText.md) | What the assistant wrote, as text, with a reminder to check it | ST-08 · ST-09 |
| [repAssistantShared](repAssistantShared.md) | The buttons' labels, outcome codes and messages | S-21 |
| [Steward_Account_Briefing](Steward_Account_Briefing.md) | Prompt template: a briefing in six headings | ST-08 |
| [Steward_Dispute_Summary](Steward_Dispute_Summary.md) | Prompt template: a first-pass summary that recommends nothing | ST-09 |
| [Steward_Followup_Draft](Steward_Followup_Draft.md) | Prompt template: a servicing email body for every outcome | ST-10 |

**The service agent (Phase 6): Apex**

| Component | One line | Stories |
|---|---|---|
| [AgentSession](AgentSession.md) | The chat's household, from the platform's record of who logged in, never from the conversation | ST-12 · S-07 · S-23 |
| [AgentActions](AgentActions.md) | What every action does around its service call: decline first, fail safely, log every request | ST-11 · ST-12 · NFR-07 |
| [GetAccountSummaryAction](GetAccountSummaryAction.md) | Balances, statements, payments and any open promise | ST-01 |
| [GetCommitmentsAction](GetCommitmentsAction.md) | What was promised at signing, through the S-08 read service | ST-02 · S-08 |
| [ExplainStatementAction](ExplainStatementAction.md) | Why a bill changed, or that the records can't say | ST-03 |
| [CheckPaymentArrangementAction](CheckPaymentArrangementAction.md) | Whether an arrangement is allowed, with the rule's figures; saves nothing | ST-04 |
| [CreatePaymentArrangementAction](CreatePaymentArrangementAction.md) | The confirmed arrangement, saved through Accord's flow, never left for approval | ST-04 · GR-03 |
| [GetDisputeReasonsAction](GetDisputeReasonsAction.md) | The eight dispute reasons and the evidence each needs | ST-06 |
| [OpenDisputeAction](OpenDisputeAction.md) | The confirmed dispute, on the household's own statement | ST-06 · S-14 |
| [GetDisputeStatusAction](GetDisputeStatusAction.md) | The household's billing disputes and where each one stands | ST-06 |
| [RecordHandoffAction](RecordHandoffAction.md) | Why the chat is going to a person, for the supervisor and the person | ST-07 · ST-11 |
| [AgentTestSessions](AgentTestSessions.md) | Stand-in chats, because a test can't open a real one | S-07 |
| [AgentTestUsers](AgentTestUsers.md) | The agent's user for tests, with only the agent's access | S-01 · ST-12 |
| [Steward Agent dashboard](Steward_Agent_Dashboard.md) | What the agent handled, handed off, declined and failed, for supervisors | ST-11 · ST-07 |

**Online payments (Phase 7)**

| Component | One line | Stories |
|---|---|---|
| [StripeClient](StripeClient.md) | Steward's only caller of Stripe: create a checkout, read it back, list completed ones | ST-05 · S-02 |
| [PaymentCheckoutService](PaymentCheckoutService.md) | Start a checkout for the household's own statement; confirm it; reconcile a page of them | ST-05 · ST-12 · S-02 |
| [CheckoutPayments](CheckoutPayments.md) | A paid session as the Lease Payment it made; dollars to cents and back | ST-05 · S-02 |
| [PaymentRecorder](PaymentRecorder.md) | Records each Stripe payment once, never overwriting one, in system mode | ST-05 · S-27 |
| [PaymentReconciliationJob](PaymentReconciliationJob.md) | The hourly safety net for customers who paid and never came back | ST-05 · S-02 |
| [IntegrationLogger](IntegrationLogger.md) | Every call to Stripe on `Integration_Log__c`, saved after the last callout | ST-05 · S-28 · NFR-07 |
| [PortalPaymentsController](PortalPaymentsController.md) | **Pay online**'s server side: start a checkout, confirm the return | ST-05 · ST-12 |
| [PortalLinks](PortalLinks.md) | A statement's portal address, from anywhere, for Stripe to send the customer back to | ST-05 |
| [GetPaymentLinkAction](GetPaymentLinkAction.md) | The agent's payment link: Stripe's page for the household's own statement | ST-05 · GR-01 |
| [portalPayment](portalPayment.md) | **Pay online** on a statement's page, and what happened when the customer comes back | ST-05 · NFR-05 |
| [StripeMock](StripeMock.md) | Stripe's answers in tests, by method and path, with every request kept | ST-05 · NFR-03 |

**The customer timeline (Phase 9)**

| Component | One line | Stories |
|---|---|---|
| [CustomerTimelineController](CustomerTimelineController.md) | One household's history, a page at a time, for the console and the portal | ST-15 · ST-12 |
| [TimelineReader](TimelineReader.md) | One user-mode query per kind, naming only fields the person can read, merged newest first | ST-15 · NFR-01 |
| [TimelineKind](TimelineKind.md) | The six kinds of event: where each lives, what dates it, what it shows | ST-15 |
| [TimelineCursor](TimelineCursor.md) | The place between pages: how many of each kind were shown | ST-15 · NFR-02 |
| [customerTimeline](customerTimeline.md) | The timeline itself: filter by kind, more as you scroll, every item reachable by keyboard | ST-15 · NFR-05 |

**Shared building blocks**

| Component | One line |
|---|---|
| [HouseholdScope](HouseholdScope.md) | Which households the caller can see: every service asks here first (ST-12) |
| [PolicySettings](PolicySettings.md) | Accord's policy numbers, read at run time, never written into code |
| [StewardOutcome](StewardOutcome.md) | The outcome and reason codes every service returns |
| [SensitiveText](SensitiveText.md) | Removes card numbers before anything is saved, and contact details before a prompt |
| [StewardTestData](StewardTestData.md) | The invented households the tests run against |
| [TestIds](TestIds.md) | A well-formed ID that no record has, for tests |

## Template

```markdown
# <ComponentName>

**What it does:** One or two sentences, in plain English.

**Why it exists:** The stories and decisions it serves (ST-xx, S-xx).

**How it works:**
1. Step one
2. Step two

**What can go wrong:** The failure cases it handles, and what the customer or rep sees in each one.

**How it's tested:** The test class or suite, and what it proves. Include the scoping test if the component touches household data.
```
