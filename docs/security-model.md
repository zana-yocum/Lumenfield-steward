# Security model — Steward

Who can reach what in Steward, and the test that proves each line. Steward adds to Accord's security model (Accord's `docs/security-model.md`). It changes none of Accord's permission sets (NFR-09). Instead, it adds its own permission sets to Accord's groups (S-22).

## The rules every class follows

- **User mode by default (NFR-01).** Every query is `WITH USER_MODE`. Every save uses `AccessLevel.USER_MODE`. Every class is `with sharing`. So a person or the agent gets exactly what their permissions and sharing allow, and no more.
- **Seven named exceptions.** Each one sits in an inner class named `Elevated`, with a comment citing its decision, and has its own tests:

| Exception | What runs in system mode | Why | Decision |
|---|---|---|---|
| Commitments read | Five fields of the commitments on a household the caller can already see | Commitments sit under the opportunity, which customers and the agent can't be given | S-08 |
| Action log write | One log record per agent action | A declined request must be logged even when the caller can't see the account, and the agent needs no access to the log | S-09 |
| Dispute insert | The case's account; every other field is checked against the caller's own create access first | Nobody can edit `Case.AccountId`, and the agent shouldn't be able to move cases between households | S-14 |
| Session lookup | A chat's session, its messaging user, and that user's account | The agent finds the household from links only the platform sets, without reading conversations or user records | S-23 |
| Payment insert | A Lease Payment for each payment Stripe confirmed, unless that Stripe payment is already recorded | Customers confirm their own payments on the portal, and nobody who confirms a payment may create payments themselves | S-27 |
| Integration log write | One log record per call to Stripe | Customers, the agent and the job's user all call Stripe, and none of them may read or write the log | S-28 |
| Production review write | One review per agreement and period, and the check for an existing one | A review is Steward's own measure; people only read it, so nobody gets create on it (Phase 8) | S-29 |

- **The household comes first (ST-12).** Every service asks `HouseholdScope` which of the given households the caller can see before it reads anything else. An ID from someone else's household gets the same answer as an ID that doesn't exist.

## Portal customers (Phase 4)

| What | Grants |
|---|---|
| Profiles **Steward Customer** and **Steward Customer Login** (S-18) | Customer Community licenses. Custom profiles, not the standard external ones |
| `PS_Steward_Customer` | The three portal controllers, the timeline's (`CustomerTimelineController`, Phase 9) and payments' (`PortalPaymentsController`, Phase 7). Calls to Stripe through the `Stripe_Test` credential's principal. Read on Account, Contact, Billing Statement, Lease Payment and Promise to Pay. Read and create on Case, with the Billing Dispute record type. Read on the balances and statement amounts. Create on the dispute fields. Nothing on commitments, opportunities, adjustments, agreements or the action log |
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
| Contact | Read | No fields. A lookup to an object the user can't read is hidden, so without this the agent couldn't read the household's primary contact or name it on a dispute. Customers have it for the same reason |
| Apex classes | The ten actions | `GetAccountSummaryAction`, `GetCommitmentsAction`, `ExplainStatementAction`, `CheckPaymentArrangementAction`, `CreatePaymentArrangementAction`, `GetDisputeReasonsAction`, `OpenDisputeAction`, `GetDisputeStatusAction`, `RecordHandoffAction`, `GetPaymentLinkAction` (Phase 7) |
| External credential | Principal access | `Stripe_Test-Stripe_Test_Key`, so Get Payment Link can ask Stripe for a checkout page (Phase 7) |

Nothing else, so it has no Delete, no Edit on any object, no View All or Modify All, and no approval rights. It also gets nothing on Opportunity, Commitment, the action log, messaging records or users, and no contact field. The services reach the commitments, the log and the session for it, through the named exceptions above.

**Record access.** Accounts, cases and service agreements are Private, and statements, payments, promises and adjustments follow their account. So the agent user gets its records through one public group:

| Component | What it gives the **Steward Agent** group |
|---|---|
| Sharing rule `Households_to_Steward_Agent` (Account, criteria) | Edit on every Residential Agreement account, Read on their cases, nothing on their contacts or opportunities. Organization accounts don't match |
| Sharing rule `Agreements_to_Steward_Agent` (Service Agreement, owner) | Read on agreements owned by internal users, so the escalator can be explained |

**Why Edit on households when the object is Read:** a promise to pay is a master-detail child of the account. With the relationship's default sharing setting, adding a child needs edit access to the parent record. The object permission still lets the agent edit no account field, and none of its actions updates an account. `AgentAccessTest` saves a promise as the agent user with exactly this access (below).

**Why every household:** the agent serves whichever customer is logged in, so the agent user needs access to every household it may serve. Which household one conversation may act for comes from the session, never from this access (S-07, S-23). So a chat reaches only its own customer's records, even though the agent user can see them all.

**Proved by:**
- `AgentAccessTest` runs the first nine actions as an Einstein Agent User with only this permission set and the group's access, and every one answers in full. `AgentPaymentAccessTest` does the same for Get Payment Link (Phase 7), with Stripe mocked. It also checks three more things:
  - From a second customer's chat, the first household's statement is not found, even though the agent user can see that household.
  - The agent user can't see an Organization account.
  - The agent user can't set a case's account, which is why the dispute insert stays an exception (S-14).
- A check-only deployment doesn't apply new sharing rules, so the test gives the group the same access by hand. The rules themselves are checked in the org after each release. On 2026-11-03, the first check:
  - The household rule shared all 88 Residential Agreement accounts with the group (Edit, cases Read), and none of the 12 Organization accounts.
  - The agreement rule shared all 100 agreements, read only. That includes the 12 on Organization accounts, which the agent never reaches.
  - Accord's own rule still shared its 34 accounts in collections.

## Collections personas (Phases 5, 6 and 9)

Steward's permission sets, in Accord's three permission set groups (S-22):

| Permission set | Grants | In |
|---|---|---|
| `PS_Steward_Rep_Assistant` | Execute Prompt Templates, and the four rep assistant classes | Collections Rep, Dispute Specialist, Collections Supervisor |
| `PS_Steward_Collections_Contact` | Read on Contact Email, Phone and MobilePhone, and Account Phone | All three |
| `PS_Steward_Dispute_Specialist` | Read on Case Subject, Description, AccountId and ContactId | Dispute Specialist, Collections Supervisor |
| `PS_Steward_Supervisor` | Read and View All on the agent's action log and its fields, for the Steward Agent dashboard | Collections Supervisor |
| `PS_Steward_Integration_Log` | Read and View All on the integration log and its tab (Phase 7) | Collections Supervisor |
| `PS_Steward_Timeline` | The customer timeline's controller, and nothing else | All three |

Reps and specialists get nothing on the action log or the integration log. The action log's outcome field is required, so it's readable with the object and isn't listed.

**Why View All on the action log:** the log is Private, and its records are owned by whoever the action ran as: the agent user, or a customer on the portal. Neither is in the role hierarchy, so read alone showed a supervisor no records at all. View All on this one object is the access the job needs, and it's read only.

**The Steward Agent dashboard** runs as whoever views it, so it shows only what that person can read: everything to a supervisor or an admin, and nothing to a rep (ST-11). Its folders are shared, view only, with the Collections Supervisor role.

## The customer timeline (Phase 9)

One component, two audiences, and no extra access for either (S-25):

- **What it can show is what the person can already read.** `TimelineReader` describes each object and field for the running user, offers only the kinds they can fully read, and selects only the fields they can read, all in user mode. It adds no exception to the four above.
- **Whose household it shows is decided on the server.** On the portal it's always the logged-in customer's own (`PortalHousehold`), whatever the page passes. In the console it's the record page's account, only if `HouseholdScope` says it's a household the user can see. Anything else is `NOT_FOUND`.
- **Customers see four kinds.** They have no access to adjustments or commitments, so credits and commitments are never offered to them. Disputes come through the `Customer_Household` sharing set, so Accord's default reviews never appear.
- **The page sends a cursor back, and it's untrusted.** It's parsed strictly, and its counts are bound as values. A count can only skip records inside the household the server already chose.

Proved by `CustomerTimelineControllerTest`: an outsider gets `NOT_FOUND`, a customer passing another household's ID still gets only their own, and a customer without one field gets events without it.

## Online payments (Phase 7)

Customers pay on Stripe's hosted checkout page, in test mode (S-02). Card details are typed on Stripe's page and never reach Salesforce, the portal or the chat.

**The key**
- Stripe's secret key is entered in Setup, as the `ApiKey` parameter of the `Stripe_Test_Key` principal on the `Stripe_Test` External Credential. It's never in code, the repository or a test.
- Apex calls `callout:Stripe_API`, and the credential adds the `Authorization` header itself. `StripeClientTest` checks Steward never sets one.

**Who can call Stripe:** only users whose permission set grants the principal.

| Permission set | Who | Why |
|---|---|---|
| `PS_Steward_Customer` | Customers | **Pay online** on a statement |
| `PS_Steward_Agent` | The agent user | Get Payment Link |
| `PS_Steward_Payment_Reconciliation` | The admin who schedules `PaymentReconciliationJob` | The job runs as that admin. This set grants the principal and nothing else |

Reps, specialists and supervisors can't call Stripe.

**Whose statement**
- A checkout starts only for a statement in the caller's own household. On the portal that's the logged-in customer's (`PortalHousehold`), and in the chat the session's verified customer (S-23).
- Coming back, the session's client reference must be one of the household's statements, or the answer is `NOT_FOUND` and nothing is recorded.
- The session ID from the address is checked for its `cs_` prefix before Stripe is asked.

**What goes to Stripe:** the statement's ID and number, the household's ID, and the amount. No name, email address, phone number or address. Stripe's page asks the customer for what it needs.

**Recording the payment**
- Only `PaymentRecorder` creates Lease Payments for Steward, in system mode (S-27), and only after Stripe says the session was paid. On the portal, the session's statement must also be the household's own. The amount and Stripe's payment ID come from Stripe, never from the page.
- Customers and the agent keep read only on Lease Payments, so they can't record a payment through the API.
- Each Stripe payment is recorded once, on its unique payment ID, however many times it's confirmed.
- A platform event was built first and dropped: publishing one needs create access on the event, and with that access anyone could publish a payment through the API (S-27).

**The integration log**
- `Integration_Log__c` is Private. Every call to Stripe is written to it in system mode (S-28), and nobody gets create, edit or delete on it.
- `PS_Steward_Integration_Log` gives read and View All, with its tab. It's in the Collections Supervisor group, so supervisors can follow a customer's reference to Stripe's answer.
- Customers, reps and the agent can't read it.

**Proved by:**
- `PortalPaymentsControllerTest` and `PaymentCheckoutServiceTest`, as customer users. Another household's statement or session is `NOT_FOUND`, and Stripe is never asked.
- `GetPaymentLinkActionTest` and `AgentPaymentAccessTest`, as the agent user: only the chat's own customer gets a link. A card number typed in place of a statement ID is refused and kept out of the log.
- `IntegrationLoggerTest`: a customer's call is recorded, though the customer can't read the log.
- **What only the org can show:** that a customer's callout works with this access. Tests mock Stripe, so they can't show the credential's principal access at work. UAT-S05 covers it with a real test-mode payment.

## The production guarantee (Phase 8)

- **One new exception: the review itself (S-29).** `ProductionGuaranteeService` writes `Production_Review__c` in system mode, like the logs, so nobody needs create on it and nobody can make one up. Agreements and statements are read, and the Draft credit is saved, in user mode, as whoever runs it. `ProductionReviewJob` runs as the admin who schedules it.
- **Who reads reviews:** `PS_Steward_Production_Review` gives read and View All on `Production_Review__c`, with its tab, in the Dispute Specialist and Collections Supervisor groups. Nobody gets create, edit or delete; reviews are opened by the service.
- **The credits are Accord's.** A review's Draft credit is an ordinary `Adjustment__c`, so Accord's rules decide who approves and posts it, and Accord's field security decides who sees it.
- **Customers and the agent see nothing of it yet.** Part 2's agent answer gives a customer their own actual and guaranteed kWh, through the same household scoping as every other action.

Proved by `ProductionGuaranteeServiceTest`: a user who can't see the households measures nothing.

## The pipeline

`PS_Steward_CI` pre-authorizes the Steward CI user for the Steward CI external client app, and grants nothing else (S-12). The user signs in by certificate only. How it's set up: `docs/pipeline.md`.
