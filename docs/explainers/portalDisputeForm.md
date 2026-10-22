# portalDisputeForm

**What it does:** Opens a dispute from the portal. The customer picks one of their statements and one of Accord's eight reasons, sees what they'll need to send before they submit, and gets the case number and the evidence list back.

**Why it exists:** ST-06, ST-12, NFR-07. Disputes stall when nobody asks for the right document. The customer sees the checklist for their reason before they send it, and again in the confirmation.

**How it works:**
1. It calls `PortalDisputesController.getDisputeForm` for the reasons, each with its evidence, and the household's statements.
2. Statements that already have an open dispute aren't offered. They're listed under "Already in dispute" with a link to that dispute.
3. Choosing a reason shows its evidence list, required items first.
4. "Open the dispute" checks a statement and a reason are chosen, and points to the first missing one, before anything is sent. The description is optional, and its help text asks the customer not to type card or bank numbers; the server removes any it finds anyway.
5. The answer replaces the form, and focus moves to its heading so a screen reader announces it:
   - opened: "Dispute N is open", the evidence list and a link to the dispute; the page is told so the list reloads
   - already in dispute: a link to the open dispute instead of a second one
   - refused or failed: one plain sentence, or a reference to quote, never an error
6. "Open another dispute" starts again with a fresh form.

**What can go wrong:** The server re-checks everything: the statement must be the household's, the reason one of the eight, and the statement not already in dispute. Its answers are explained in the customer's own words.

**How it's tested:** `portalDisputeForm.test.js`: disputed statements aren't offered but are linked; the evidence shows as soon as a reason is chosen; nothing is sent until both choices are made; the opened result, with focus on its heading and the event to the page; the existing-dispute answer; a failure that shows only its reference; the not-found wording; and starting again. The server side is `PortalControllersTest`.
