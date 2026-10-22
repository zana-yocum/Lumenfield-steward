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

**Shared building blocks**

| Component | One line |
|---|---|
| [HouseholdScope](HouseholdScope.md) | Which households the caller can see: every service asks here first (ST-12) |
| [PolicySettings](PolicySettings.md) | Accord's policy numbers, read at run time, never written into code |
| [StewardOutcome](StewardOutcome.md) | The outcome and reason codes every service returns |
| [SensitiveText](SensitiveText.md) | Removes card numbers before anything is saved |
| [StewardTestData](StewardTestData.md) | The invented households the tests run against |

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
