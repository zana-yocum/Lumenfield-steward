# StripeMock

**What it does:** Stands in for Stripe in Apex tests. It answers each request by method and path, keeps every request so a test can check what Steward sent, and builds Stripe-shaped bodies: sessions (`StripeMock.Session`, unpaid until `paidBy`), list pages (`lastPage`, `pageWithMore`) and errors.

**Why it exists:** ST-05, NFR-03. No test may call out, and every payment test needs Stripe's answers to be known in advance: paid, unpaid, refused, timed out, and pages that do or don't have more after them.

**How it works:**
1. `answer(route, status, body)` queues an answer for a route such as `POST /v1/checkout/sessions`. Answers go out in order, and the last one repeats.
2. A route with no answer gets Stripe's 404 shape. `timesOut = true` makes every call throw the way a timeout does.
3. `new StripeMock.Session(id, statementId, cents)` builds an open, unpaid session. `.paidBy('pi_…')` makes it complete and paid, with the payment's ID and no page left to pay on.

**What can go wrong:** It answers by the path after the named credential, so a test fails at once if a call goes anywhere but `callout:Stripe_API`.

**How it's tested:** By every payment test that uses it.
