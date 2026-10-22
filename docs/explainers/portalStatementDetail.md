# portalStatementDetail

**What it does:** A statement's own page, for the statement named in the address (`/statement?recordId=…`).

**Why it exists:** ST-01, ST-12. A customer can bookmark or share a link to one statement. Whatever ID is in the address, the server decides what's shown, so changing it can't reach another household's statement.

**How it works:**
1. It reads the record ID from the current page reference and calls `PortalAccountController.getStatement` with it.
2. The server looks for the ID only among the logged-in household's statements, so another household's ID gets the same answer as one that doesn't exist: "We can't show this statement. It isn't on your account, or it doesn't exist."
3. If the address changes to another statement, it loads again; the same address doesn't load twice. An answer that arrives after the customer has moved on is ignored.

**What can go wrong:** No ID in the address shows the not-found message without asking the server. A failure shows a reference, a lost connection a plain message.

**How it's tested:** `portalStatementDetail.test.js`: the statement in the address is asked for and shown; another household's gets the no-access message; no ID asks the server nothing; and a new ID loads again, the same one doesn't. The server side is `PortalControllersTest`.
