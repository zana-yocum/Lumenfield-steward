# Security model — Steward

Who can reach what in Steward, and the test that proves each line. Steward adds to Accord's security model (Accord's `docs/security-model.md`). It changes none of Accord's permission sets (NFR-09). Instead, it adds its own permission sets to Accord's groups (S-22).

## The rules every class follows

- **User mode by default (NFR-01).** Every query is `WITH USER_MODE`. Every save uses `AccessLevel.USER_MODE`. Every class is `with sharing`. So a person or the agent gets exactly what their permissions and sharing allow, and no more.
- **Four named exceptions.** Each one sits in an inner class named `Elevated`, with a comment citing its decision, and has its own tests:

| Exception | What runs in system mode | Why | Decision |
|---|---|---|---|
| Commitments read | Five fields of the commitments on a household the caller can already see | Commitments sit under the opportunity, which customers and the agent can't be given | S-08 |
| Action log write | One log record per agent action | A declined request must be logged even when the caller can't see the account, and the agent needs no access to the log | S-09 |
| Dispute insert | The case's account; every other field is checked against the caller's own create access first | Nobody can edit `Case.AccountId`, and the agent shouldn't be able to move cases between households | S-14 |
| Session lookup | A chat's session, its messaging user, and that user's account | The agent finds the household from links only the platform sets, without reading conversations or user records | S-23 |

- **The household comes first (ST-12).** Every service asks `HouseholdScope` which of the given households the caller can see before it reads anything else. An ID from someone else's household gets the same answer as an ID that doesn't exist.

## Portal customers (Phase 4)

| What | Grants |
|---|---|
| Profiles **Steward Customer** and **Steward Customer Login** (S-18) | Customer Community licenses. Custom profiles, not the standard external ones |
| `PS_Steward_Customer` | The three portal controllers. Read on Account, Contact, Billing Statement, Lease Payment and Promise to Pay. Read and create on Case, with the Billing Dispute record type. Read on the balances and statement amounts. Create on the dispute fields. Nothing on commitments, opportunities, adjustments, agreements or the action log |
| Sharing set `Customer_Household` | Read on the customer's own account, which statements, payments and promises follow. Read on cases whose `Customer_Household__c` is that account, so Accord's default reviews stay internal (S-16) |

Proved by `PortalControllersTest`, `DisputeStatusServiceTest` and `PortalHouseholdTest`, which run as customer users with another household's IDs.

## The service agent (Phase 6)

The agent user is created with the agent, on the **Einstein Agent User** profile. On 2026-11-03 that profile granted no object permissions at all. So everything below is the whole of the agent's access (S-01).

**`PS_Steward_Agent`**

| Object | Access | Fields |
|---|---|---|
| Account | Read | Read: `Account_Status__c`, `Broken_Promises_90d__c`, `Current_Balance__c`, `Past_Due_Balance__c`, `Oldest_Past_Due_Date__c`, `Primary_Contact__c`. None editable |
| Billing Statement | Read | Read: amount due, amount paid, credits applied, balance, dispute open, due date, statement date, status, agreement |
| Lease Payment | Read | Date and amount only (required fields, readable with the object). No method, no processor reference |
| Adjustment | Read | Read: type, amount, posted date, status, statement |
| Service Agreement | Read | Read: `Escalator_Rate__c`, `First_Due_Date__c`, `StartDate` |
| Promise to Pay | Read, Create | Date, amount and status (required fields). Read: `Grace_Ends__c` |
| Case | Read, Create | Read: `AccountId`. Create: contact, description, dispute reason, disputed statement, origin, subject. Record type: Billing Dispute |
| Apex classes | The nine actions | `GetAccountSummaryAction`, `GetCommitmentsAction`, `ExplainStatementAction`, `CheckPaymentArrangementAction`, `CreatePaymentArrangementAction`, `GetDisputeReasonsAction`, `OpenDisputeAction`, `GetDisputeStatusAction`, `RecordHandoffAction` |

Nothing else, so it has no Delete, no Edit on any object, no View All or Modify All, and no approval rights. It also gets nothing on Contact, Opportunity, Commitment, the action log, messaging records or users. The services reach the commitments, the log and the session for it, through the named exceptions above.

**Record access.** Account, Case, Contact and Service Agreement are Private, and the detail objects follow the account. So the agent user gets its records through one public group:

| Component | What it gives the **Steward Agent** group |
|---|---|
| Sharing rule `Households_to_Steward_Agent` (Account, criteria) | Edit on every Residential Agreement account, Read on their cases, nothing on their contacts or opportunities. Organization accounts don't match |
| Sharing rule `Agreements_to_Steward_Agent` (Service Agreement, owner) | Read on agreements owned by internal users, so the escalator can be explained |

**Why Edit on households when the object is Read:** a promise to pay is a master-detail child of the account. With the relationship's default sharing setting, adding a child needs edit access to the parent record. The object permission still lets the agent edit no account field, and none of its actions updates an account. `AgentAccessTest` saves a promise as the agent user with exactly this access (below).

**Why every household:** the agent serves whichever customer is logged in, so the agent user needs access to every household it may serve. Which household one conversation may act for comes from the session, never from this access (S-07, S-23). So a chat reaches only its own customer's records, even though the agent user can see them all.

**Proved by:**
- `AgentAccessTest` runs all nine actions as an Einstein Agent User with only this permission set and the group's access, and every one answers in full. It also checks three more things:
  - From a second customer's chat, the first household's statement is not found, even though the agent user can see that household.
  - The agent user can't see an Organization account.
  - The agent user can't set a case's account, which is why the dispute insert stays an exception (S-14).
- A check-only deployment doesn't apply new sharing rules, so the test gives the group the same access by hand. The rules themselves are checked in the org after each release: share rows from each rule exist for the Steward Agent group on every household and every agreement, and on no Organization account.

## Collections personas (Phases 5 and 6)

Steward's permission sets, in Accord's three permission set groups (S-22):

| Permission set | Grants | In |
|---|---|---|
| `PS_Steward_Rep_Assistant` | Execute Prompt Templates, and the four rep assistant classes | Collections Rep, Dispute Specialist, Collections Supervisor |
| `PS_Steward_Collections_Contact` | Read on Contact Email, Phone and MobilePhone, and Account Phone | All three |
| `PS_Steward_Dispute_Specialist` | Read on Case Subject, Description, AccountId and ContactId | Dispute Specialist, Collections Supervisor |
| `PS_Steward_Supervisor` | Read on the agent's action log and its fields | Collections Supervisor |

Reps and specialists get nothing on the action log. The log's outcome field is required, so it's readable with the object and isn't listed.

## The pipeline

`PS_Steward_CI` pre-authorizes the Steward CI user for the Steward CI external client app, and grants nothing else (S-12). The user signs in by certificate only. How it's set up: `docs/pipeline.md`.
