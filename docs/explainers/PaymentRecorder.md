# PaymentRecorder

**What it does:** Records the payments Stripe confirmed as Lease Payments (`Payment__c`), once. `PaymentCheckoutService` calls it after Stripe says a session was paid: when the customer comes back to the portal, and when reconciliation lists the session.

**Why it exists:** ST-05, S-02, S-27. The same payment can be confirmed twice, once on each path. It must be recorded once, and a payment already on the books must never be overwritten. And neither customers nor the agent can create Lease Payments, so recording needs one controlled way in.

**How it works:**
1. Payments without a Stripe payment ID are ignored, and two of the same ID in one call become one. A date after today becomes today.
2. Payment IDs already on a Lease Payment are skipped. Accord's `External_Reference__c` is a unique external ID, so if two confirmations race, the unique index refuses the second, and that counts as recorded already.
3. The rest are inserted in system mode, in its `Elevated` inner class.
4. It returns three counts: recorded now, recorded already, and refused.
5. A refusal for any other reason, such as a locked statement, is noted on the integration log as **Record payment**, with where the confirmation came from, Stripe's payment ID and the platform's reason. The caller saves the log after its last callout (S-28).

**Why system mode (S-27):** customers and the agent have read only on Lease Payments, so they can't record payments through the API. Every payment that reaches this class was read back from Stripe as paid. On the portal, its statement was also checked to be the household's own. A platform event was built first, and the org refused it: publishing one needs create access on the event, which customers mustn't have.

**What can go wrong:** A refused payment isn't lost. Stripe still lists the session for the next 48 hours, so the next hourly reconciliation run records it. The customer was already told it's received, and that it will show within the hour.

**How it's tested:** `PaymentRecorderTest`:
- a payment recorded with its statement, amount, date and method
- the same payment twice in one call, recorded once
- a payment already recorded, left as it was, even with a different amount
- a refused payment noted for support, while the good one is recorded
- a date after today recorded as today
- nothing to record makes no save
