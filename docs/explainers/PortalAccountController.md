# PortalAccountController

**What it does:** Serves the portal's My account, Statements and statement pages: the logged-in household's balances, statements, payments and open promise, and one statement on its own.

**Why it exists:** ST-01, ST-12, NFR-07. Customers should see where they stand without calling, and the numbers must match what a rep sees. The controller adds no logic of its own: it finds the household and asks Phase 3's `AccountSnapshotService`, which the agent will use too, so the portal and the agent can't disagree.

**How it works:**
1. `getMyAccount()` gets the household from `PortalHousehold` and returns `AccountSnapshotService.getSnapshot` for it.
2. `getStatement(statementId)` takes the ID from the page's address, reads the same snapshot, and looks for the ID among the household's own statements. Another household's statement isn't in that list, so it gets `NOT_FOUND`, the same answer as an ID that doesn't exist.
3. Neither method takes an account ID. The page isn't the security boundary; the server is (ST-12).
4. An exception goes to `PortalFailure`, and the customer gets a reference to quote.

**What can go wrong:** A user with no household gets `INVALID_REQUEST`. A statement ID from another household gets `NOT_FOUND` and nothing about the statement. An exception comes back as `FAILED` with a reference.

**How it's tested:** `PortalControllersTest`, as a real customer user. My account matches the account's own balances to the cent and lists only that household's three statements. The household's own statement comes back with its $50 payment; another household's statement ID is `NOT_FOUND` with nothing returned. An internal user gets `INVALID_REQUEST`, and an exception becomes a reference.
