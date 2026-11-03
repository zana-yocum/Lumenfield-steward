# GetDisputeReasonsAction

**What it does:** Returns the eight reasons a customer can dispute a statement for, each with the evidence it needs, required items first. The list comes from Accord's own checklist (`DisputeEvidenceCatalog`).

**Why it exists:** ST-06, GR-04. The agent uses the list to match what the customer says to a reason, and to tell them what to send. Each reason's value is passed to Open Dispute exactly as given, so the model never invents a reason.

**How it works:**
1. The only input is `sessionId`. The list holds no household data, but the chat must still have a logged-in customer behind it, like any other action.
2. The catalog is read once per call and turned into reasons with their evidence lines.
3. Every request writes one log record, "Dispute reasons".

**What can go wrong:** The same declines as every action. An exception gives `FAILED` and a reference.

**How it's tested:** `GetDisputeReasonsActionTest`:
- Every reason is listed, with its evidence and the required items first.
- An anonymous chat gets nothing.
- A failure gives a reference.
