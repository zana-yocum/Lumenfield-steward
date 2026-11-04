# portalPayment

**What it does:** **Pay online** on a statement's own portal page. **Pay $120.00** sends the customer to Stripe's secure checkout page for the balance. When Stripe sends them back, the page says whether the payment went through.

**Why it exists:** ST-05, ST-12, NFR-05, NFR-07. A customer pays when they think of it, and card details are typed on Stripe's page, never into Lumenfield's.

**How it works:**
1. **Pay** shows only when there's a balance. It calls `PortalPaymentsController.startPayment` and navigates to Stripe's page (`standard__webPage`). While the page opens, the button says so and ignores another click.
2. **Coming back.** `portalStatementDetail` reads `c__session_id` from the address, which Stripe filled in, and passes it in. The component calls `confirmPayment` once:
   - **Paid:** "Thank you. Your payment of $120.00 is received." The Pay button goes away. If the payment is on the statement already, which is the usual case, the component fires `refresh`, and the statement page reads the statement again, so the payment and the new balance appear in place. If the platform refused the record for now, the page adds "It will show on this statement within the hour."
   - **Not paid:** "No payment was taken". The same message shows when `c__payment=cancelled` says the customer went back from Stripe.
   - **Not this household's:** a message saying the payment couldn't be found.
3. Status messages are a polite live region. Problems are alerts.

**What can go wrong:** If Stripe is unavailable, the customer sees "Online payment isn't available right now," with a reference. A lost connection gets its own message, and nothing on the statement is cleared by a failure. The text is `Steward_Portal_Pay_*` labels.

**How it's tested:** `portalPayment.test.js`, 12 tests:
- the Pay button and the secure note
- navigation to Stripe's page for this statement
- no button with nothing owed
- unavailable with a reference, nothing owed, and a lost connection without details
- thanks on a paid return, with the refresh event fired on its own
- thanks, and the within-the-hour note, when the payment isn't on the statement yet
- not taken, cancelled, not found, and a reference when the check fails

Each state passes the accessibility check. `portalStatementDetail.test.js` checks the page hands over the balance, the session and a cancel, and refreshes the statement in place.
