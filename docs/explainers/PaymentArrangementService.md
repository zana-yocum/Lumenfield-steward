# PaymentArrangementService

**What it does:** Checks whether a household can arrange a payment date on its own and, when the customer confirms, creates the Promise to Pay. Accord's flow then puts the account on hold until the grace period ends.

**Why it exists:** ST-04, ST-12, GR-02, GR-03. Customers who are behind should be able to catch up without waiting on hold, but only on terms a rep could agree to alone. The service gives the customer a clear answer first, such as "the latest date I can arrange is November 17". The save itself still goes through Accord's flow and formula, which read the same policy records (S-03).

**How it works:**
1. `checkEligibility` runs the checks and saves nothing. The agent uses it before asking the customer to confirm (GR-05).
2. `createArrangements` runs the same checks (`ArrangementEligibility`), then keeps at most one request per household: Accord allows one active promise, so a second request for the same household in the batch is declined.
3. It sets a savepoint and inserts the promises as Active, in user mode, so the caller's own access applies.
4. Accord's `Promise_AfterSave_ApplyPolicy` flow runs on the save. A promise in policy stays Active and sets the account's Collection Hold Until. A promise that Accord's `Out_of_Policy__c` formula flags (less than the past-due balance, or past the window) is moved to Pending Approval.
5. The service reads each promise back. Active: `COMPLETED`, with the promise number and hold date. Anything else: `WOULD_NEED_APPROVAL`.
6. If any promise ended up Pending Approval, the whole save is rolled back and only the ones that stayed Active are saved again. Nothing is ever left for a supervisor to approve (GR-03).

**What can go wrong:**
- A rule says no: `DECLINED_POLICY` with the reason and the figures the customer needs (the latest allowed date, the minimum amount, or the existing promise's amount and date).
- Account status or recent broken promises: `HANDOFF`, with no collections figures revealed.
- The save fails: `FAILED` with `SAVE_FAILED`. The platform's message goes in `failureDetail`, which is for the log only (NFR-07).
- Steward's checks and Accord's formula disagree, for example after someone changes a policy record without changing the other side: the rollback catches it, and the customer is told it needs a person.

**How it's tested:** `PaymentArrangementServiceTest`, with policy values read from Accord's records, never assumed. A promise inside policy saves as Active, and the test reads the account back to prove Accord's flow set the hold to the promise date plus the grace days. The window's last day is allowed and the day after is declined with the latest date. A past date is declined. $189.99 against $190.00 past due is declined with the minimum. An Active or Pending Approval promise is reported, not duplicated. Default Review, Hardship Review and Closed accounts, and too many broken promises, hand off with no figures. Nothing past due, incomplete requests, and a household the caller can't see are each handled. Checking saves nothing. Rollback test: Steward's window is made wider than Accord's, so a promise passes Steward's check and Accord sends it for approval. The test proves it was rolled back, no hold was set, and the other promise in the same call still saved. One promise per household per batch. 200 households in one call.
