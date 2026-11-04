# PortalPaymentsController

**What it does:** The server side of the portal's **Pay online**. `startPayment` returns Stripe's checkout page for one of the customer's statements. `confirmPayment` says whether the checkout the customer came back from was paid, and records the payment if it was.

**Why it exists:** ST-05, ST-12, NFR-07. It's thin, like every portal controller. The household comes from the login (`PortalHousehold`), never from the page.

**How it works:**
1. With no household, as for an admin previewing the site, the answer is `INVALID_REQUEST`. With no statement, it's `NOT_FOUND`.
2. Otherwise `PaymentCheckoutService` does the work.
3. The calls to Stripe are saved (`IntegrationLogger.save`) after the last one, and return their numbers.
4. A failure goes through `PortalFailure`. The action log records the reason and Stripe's error, and names the integration log record, such as `PROVIDER_UNAVAILABLE: Stripe answered 500 … (INT-000012)`. The customer gets only the action log's number to quote.

**What can go wrong:** Any exception becomes `FAILED` with a reference, never the error. `failureDetail` is cleared before anything reaches the browser.

**How it's tested:** `PortalPaymentsControllerTest`, as customer users:
- a customer starts paying their own statement, and the call is logged
- another household's statement is NOT_FOUND, with Stripe never asked
- an internal user is turned away from both methods, and an empty statement ID is NOT_FOUND
- Stripe down gives a reference, and the action log names the integration log
- a paid checkout coming back is recorded at once
- no answer on the way back gives a reference
- anything unexpected gives a reference
