# CheckoutPayments

**What it does:** Reads a paid Stripe checkout session as the Lease Payment it made: the statement Steward named when it created the session, what Stripe says was paid, the day, and Stripe's payment ID. It also converts amounts between dollars and the cents Stripe works in (`toCents`, `toDollars`).

**Why it exists:** ST-05, S-02. `PaymentCheckoutService` decides whether a payment counts. This class says what that payment looks like as a record, so each stays small enough to read in one go.

**How it works:**
1. `toPayment(session)` returns nothing for a session that isn't paid, has no payment ID, or whose client reference isn't a statement's ID. Otherwise it returns an unsaved Lease Payment, by card, on that statement.
2. **The amount** is Stripe's, converted from cents.
3. **The day** is the day the session was created, which Stripe keeps open for an hour, in the running user's time zone. It's never later than today, because Accord refuses a payment dated in the future.
4. **The external reference** is Stripe's payment ID (`pi_…`), not the session's ID. The payment ID is what identifies the money, and it fits Accord's 64-character unique field; a session ID can be longer.
5. `toCents` rounds half a cent up. Apex's `Decimal` has no `movePointRight`, as the first validation found.

**What can go wrong:** A client reference that isn't a statement's ID gives no payment (`statementIdOrNull`), so reconciliation skips it.

**How it's tested:** `CheckoutPaymentsTest`:
- a paid session reads as its payment, field by field
- an unpaid session, one without a payment ID, one for something other than a statement, and no session at all each give nothing
- a session dated after today is paid today
- the conversions both ways, and that only a statement's ID counts as a statement
