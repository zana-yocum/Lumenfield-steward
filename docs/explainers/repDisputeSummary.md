# repDisputeSummary

**What it does:** The Dispute Summary button on a billing dispute. It writes the summary as soon as the panel opens, shows it, and writes it again on request.

**Why it exists:** ST-09, S-21. A specialist starts from one summary instead of five places.

**How it works:**
1. It's a screen quick action (`Case.Steward_Dispute_Summary`) on the Billing Dispute layout. When it gets the case's ID, it calls `RepAssistantController.disputeSummary` once.
2. `repGeneratedText` shows the spinner, then the summary or the reason there isn't one.
3. **Write again** asks again; **Close** closes the panel.

**What can go wrong:** A case that isn't a billing dispute the person can see gets the not-found message; the server makes that call, not the button.

**How it's tested:** `repDisputeSummary.test.js` (4 tests): the summary for the case on the page (with `toBeAccessible`); the not-found message; a server error with its detail; Write again and Close.
