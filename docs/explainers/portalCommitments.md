# portalCommitments

**What it does:** The What we promised you page: each special term recorded on the household's agreement at signing, with its type, value, months covered, status and the terms as recorded.

**Why it exists:** ST-02, S-08. Neither the customer nor the person they call should have to rely on memory of what a salesperson said.

**How it works:**
1. It calls `PortalCommitmentsController.getMyCommitments`, which reads through Steward's one elevated read service (S-08) and returns five fields only.
2. The terms are shown in quotation marks, exactly as recorded, under "As recorded at signing".
3. A link to open a dispute follows the list, for anything missing or wrong.
4. When nothing was recorded, the page says so and explains how to open a Promised Credit Not Applied dispute.

**What can go wrong:** No household, a failure or a lost connection each show one plain message. Nothing about the deal, the sales rep or who recorded a commitment ever reaches the page, because the server never reads it.

**How it's tested:** `portalCommitments.test.js`: each commitment's fields and terms as recorded, the nothing-recorded wording with its dispute link, and a failure showing only a reference, each passing the accessibility check.
