# portalMyAccount

**What it does:** The portal's home page: the household's current balance, past-due amount, oldest unpaid statement, next payment due, and any payment arrangement, with a link to the statements.

**Why it exists:** ST-01. A customer should see where they stand without calling, and the numbers must match what a rep sees.

**How it works:**
1. It calls `PortalAccountController.getMyAccount`, which reads the logged-in household through `AccountSnapshotService`.
2. Every figure is Accord's roll-up, shown as it comes back. Nothing is calculated in the browser.
3. "Oldest unpaid statement" says None when nothing is past due, and "Next payment due" says Nothing due when nothing is owed.
4. An open promise to pay shows as one sentence: the amount, the date and its status.

**What can go wrong:** No household, a server failure or a lost connection each show one plain message (from `portalShared`). A failure shows only a reference to quote.

**How it's tested:** `portalMyAccount.test.js`: Accord's figures to the cent, the nothing-owed wording, a failure showing only its reference, and a lost connection showing no error details. Each state passes the accessibility check. The server side is `PortalControllersTest`.
