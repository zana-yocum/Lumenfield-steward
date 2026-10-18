# AccountSnapshotService

**What it does:** Returns where a household stands: current balance, past-due balance, the oldest past-due date, the next amount due and when, every statement newest first with its payments, any open dispute on a statement, and any open promise to pay.

**Why it exists:** ST-01, ST-12, GR-04. The portal's My Account page and the agent's answer to "what do I owe?" need the same numbers a rep sees. They come from Accord's roll-ups and formulas (`Current_Balance__c`, `Past_Due_Balance__c`, `Balance__c`), which this service reads and never recalculates. A second calculation would sooner or later give a customer a different number than the rep sees.

**How it works:**
1. `HouseholdScope` decides which requested households the caller can see. The rest are `NOT_FOUND`, and nothing more is read for them.
2. Five more queries, all in user mode, however many households are asked for: balances from the account, statements, payments on those statements, open Billing Disputes on them, and open promises (Active or Pending Approval).
3. Payments carry only date and amount. The payment method and processor reference are supervisor-only in Accord, and the service doesn't select them (ST-01).
4. The next amount due is the Open statement with a balance and the earliest due date.
5. A disputed statement carries the open case's ID and number, if the caller can see the case.

**What can go wrong:** A household out of reach is `NOT_FOUND`, the same as one that doesn't exist. A null ID is `INVALID_REQUEST`. A household with no statements gets a snapshot that owes nothing, not an error. Because every query is in user mode, a caller missing access to a field gets an error instead of a quiet gap. That shows up while the agent's permission set is built and tested in Phase 6, not in front of a customer.

**How it's tested:** `AccountSnapshotServiceTest`, with known-answer data. One household has a paid statement, two past-due statements (one partly paid, $50 of $120), an upcoming one, and a $190 promise. The test expects exactly $310.00 owed, $190.00 past due, the right oldest past-due date, the next $120.00 due in 14 days, and a grace end of the promise date plus Accord's grace days. Other tests check that statements are newest first with their payments, that a payment carries only date and amount, and that a disputed statement shows In Dispute with its case number. A household with no statements owes nothing. Users who can't see the household, Organization accounts and null IDs are refused. 200 households are read with six queries.
