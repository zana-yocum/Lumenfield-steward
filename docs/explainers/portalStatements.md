# portalStatements

**What it does:** The Statements page: every statement the household has, newest first, each as a `portalStatementCard` whose number links to the statement's own page.

**Why it exists:** ST-01. Customers should see each statement's dates and amounts, and which payments paid it, without asking.

**How it works:**
1. It calls `PortalAccountController.getMyAccount`, the same read as My account, so the two pages always agree.
2. It shows the statements in the order the server sends them, newest first, one card each.

**What can go wrong:** No statements yet says so. No household, a failure or a lost connection each show one plain message.

**How it's tested:** `portalStatements.test.js`: one card per statement in the server's order, the empty state, and the message for someone without a household, each passing the accessibility check.
