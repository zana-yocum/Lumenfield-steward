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
