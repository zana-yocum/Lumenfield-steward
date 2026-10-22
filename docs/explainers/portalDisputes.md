# portalDisputes

**What it does:** The Disputes page: the form for opening a dispute (`portalDisputeForm`), then the household's disputes, newest first, each linking to its own page.

**Why it exists:** ST-06. A customer who thinks a bill is wrong can say so here, and see every dispute they've opened.

**How it works:**
1. It calls `PortalDisputesController.getMyDisputes` and lists each dispute's number, status, reason, statement and opening date.
2. When the form opens a dispute, it fires `disputeopened`, and the list loads again, so the new dispute appears straight away.

**What can go wrong:** No disputes yet says so. No household, a failure or a lost connection each show one plain message.

**How it's tested:** `portalDisputes.test.js`: the list with each dispute's link, the empty state, and the reload when the form opens a dispute, each passing the accessibility check.
