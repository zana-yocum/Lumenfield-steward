# StripeClient

**What it does:** Steward's only caller of Stripe. It has three calls: create a checkout session for one statement's balance, read a session back, and list completed sessions for reconciliation.

**Why it exists:** ST-05, S-02. Every call to Stripe goes through one class, so the key, the request shape, the timeouts and the logging are written once.
- **No key in the code.** It calls `callout:Stripe_API`, the named credential, and the Stripe Test external credential adds the bearer token. The key lives on the credential's principal, entered in Setup, never in code or the repository.
- **Access is controlled.** Only users whose permission set reaches that principal can call Stripe at all.

**How it works:**
1. **Create checkout session** posts a form to `/v1/checkout/sessions`:
   - the statement as `client_reference_id`, and in the metadata with the household
   - the balance in cents, as a one-line card payment in US dollars
   - a return address with Stripe's `{CHECKOUT_SESSION_ID}` placeholder, and a cancel address
   - an expiry an hour out
   - an `Idempotency-Key`: the statement, the amount and a random part, so a repeated request can't create a second session

   No contact details are sent. Stripe's page asks for what it needs.
2. **Read checkout session** reads one session's status, payment status, client reference, amount and payment ID. The payment ID can arrive as a string or, when expanded, as an object, and both are read.
3. **List completed sessions** reads 100 at a time, created since a moment, using `starting_after` for the next page.
4. Every call is recorded with `IntegrationLogger` as it happens: operation, outcome, HTTP status, duration, household, statement and Stripe's ID. The records are saved after the transaction's last callout.

**What can go wrong:** Anything but a 2xx answer, a timeout, or an answer that isn't JSON throws `StripeException`. The log keeps Stripe's error type, code and message, which name the parameter at fault, never a key or card details. Callers turn the exception into `PROVIDER_UNAVAILABLE` and a reference for the customer.

**How it's tested:** `StripeClientTest`, against `StripeMock`, so no test calls out. It checks:
- the endpoint is the named credential and Steward never sets an Authorization header
- the idempotency key's shape
- the client reference, the amount in cents and the return address
- that no email address is sent
- a refusal (402), a timeout and a non-JSON answer, each logged as a failure
- an expanded payment ID
- the list's filters and paging
