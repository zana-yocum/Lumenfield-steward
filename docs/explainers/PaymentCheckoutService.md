# PaymentCheckoutService

**What it does:** Pays a statement online. It has three entry points:
- `startCheckout` makes a Stripe checkout session for one of the household's statements, for its balance, and returns the page to send the customer to.
- `confirm` asks Stripe whether the session a customer came back from was paid, and if it was, records the payment.
- `reconcile` does the same for every completed session on one page of Stripe's list.

**Why it exists:** ST-05, ST-12, S-02. A customer should be able to pay when they think of it, without card details ever touching Salesforce or the chat. And a payment has to be recorded exactly once, whether the customer comes back to the portal or closes the browser.

**How it works:**
1. **Start.**
   - It reads the statement in user mode, only among the household's own, after `HouseholdScope`. With no statement given, it takes the oldest one with a balance.
   - A statement out of reach is `NOT_FOUND`. One with nothing owed is `NOTHING_OWED`. Stripe is never asked about either.
   - It asks for the balance in cents. The return address is the statement's own portal page (`PortalLinks`), with `c__session_id={CHECKOUT_SESSION_ID}` for Stripe to fill in. The cancel address is the same page with `c__payment=cancelled`.
2. **Confirm.**
   - A session ID that doesn't start with `cs_` is refused before Stripe is asked.
   - The session's client reference has to be one of the household's statements. Anyone else's session is `NOT_FOUND`, and nothing is published.
   - An unpaid session is `NOT_PAID`.
   - A paid session becomes a Lease Payment (`CheckoutPayments`), with Stripe's amount and payment ID, and `PaymentRecorder` records it once.
   - The answer says whether it's on the statement now (`recorded`). The customer is told it's received either way, because Stripe has the money.
3. **Reconcile.** It records every paid session whose client reference is a statement's ID, and counts what was recorded, recorded already and refused. It doesn't check whose: reconciliation runs as the job's user, and `PaymentRecorder` records each payment once.

**What can go wrong:**
- **Stripe down or refusing:** `FAILED` / `PROVIDER_UNAVAILABLE`. Stripe's error goes in `failureDetail`, for the log only.
- **Paid but refused by the platform for now:** still `COMPLETED`, with `recorded` false. The refusal is noted on the integration log, and the next reconciliation run records it.
- **During reconciliation:** a failure to reach Stripe throws, and the job logs it.
- **Callout order:** every callout comes before every save, so a payment never fails on Salesforce's callout-after-save rule.

**How it's tested:** `PaymentCheckoutServiceTest`, as customer users, with all data made in the setup:
- the balance in cents and the return address
- another household's statement and session, NOT_FOUND with Stripe never asked
- nothing owed, and the oldest statement with a balance
- Stripe down, and no answer on the way back
- a paid session recorded at once, with its statement, amount, card method and date
- an unpaid session recording nothing
- a bad session ID
- reconciliation recording one payment seen twice once, every household's payment, and nothing without a statement
