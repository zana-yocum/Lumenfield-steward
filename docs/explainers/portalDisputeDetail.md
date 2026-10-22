# portalDisputeDetail

**What it does:** A dispute's own page, for the dispute named in the address (`/dispute?recordId=…`): its status, reason, opening date and statement, what to send (required and optional), and an upload area while it's open.

**Why it exists:** ST-06, ST-12. The customer sees where their dispute stands and sends the evidence it needs in one place. The root cause, internal comments and the sales team never appear, because the server doesn't send them.

**How it works:**
1. It reads the record ID from the address and calls `PortalDisputesController.getDispute`, which looks for it only among the household's billing disputes.
2. The evidence list shows each item as Required or Optional.
3. While the dispute is open, a file upload takes PDFs and photos, several at a time, and attaches them to the case, where Accord's specialists work it. A message confirms how many files arrived. A closed dispute takes no new files and says so.
4. Like the statement page, it loads again only when the address names a different dispute.

**What can go wrong:** Another household's dispute, a default review or a missing ID all get "We can't show this dispute. It isn't on your account, or it doesn't exist." A failure shows a reference, a lost connection a plain message.

**How it's tested:** `portalDisputeDetail.test.js`: the dispute with its evidence and the upload area, the thank-you message, no upload once closed, the no-access message, and no server call without an ID. That a customer's file can attach to their own dispute and not another household's is proven in Apex (`PortalControllersTest`).
