# PaymentReconciliationJob

**What it does:** The safety net for online payments. Scheduled, it asks Stripe for every completed checkout in the last `Payment_Reconciliation_Hours` (48) and records each paid one, for customers who paid and closed the browser before coming back.

**Why it exists:** ST-05, S-02. Salesforce asks Stripe; Stripe never calls Salesforce, so there's no public endpoint to secure. The cost is a delay for a customer who doesn't come back, and this job bounds it.

**How it works:**
1. **Scheduled.** It works out its window from the policy setting and starts one queueable, which can call out.
2. **Each page.** Each queueable reads 100 sessions (`PaymentCheckoutService.reconcile`), records the paid ones, and starts the next page from the last session read. It stops after 20 pages, and the next run carries on.
3. **Safe to repeat.** `PaymentRecorder` skips payments already recorded, so running the job any number of times records each payment once. A payment the platform refused on one run is recorded on the next, while Stripe still lists it.
4. **A finalizer, `Watch`,** is attached to each page's job. If the job ends with an exception it didn't handle, such as a limit, `Watch` logs **Reconciliation failed** with the page and the error.

**What can go wrong:** If Stripe is down or refuses, the call is already on `Integration_Log__c`. The job adds **Reconciliation stopped** and ends, and the next scheduled run tries again. A test can't start a queueable from a queueable, so in a test each job is kept in `nextInTest` and the test runs it.

**How it's tested:** `PaymentReconciliationJobTest`:
- a run asks for the policy's window and records the payment it finds
- a page with more starts the next from the last session
- Stripe down logs the call and the stop, with no next page
- the finalizer logs an unhandled error and adds nothing after a good run
