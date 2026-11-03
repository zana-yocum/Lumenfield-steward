# GetDisputeStatusAction

**What it does:** The agent's answer to "where is my dispute?" It returns the logged-in customer's billing disputes, open and closed, newest first. For each one: the case number, the status, whether it's closed, the reason, the statement, and the date it was opened.

**Why it exists:** ST-06, ST-12. A customer shouldn't have to call to learn that a dispute is still being worked. Only billing disputes are returned. Accord's Default Reviews on the same account are internal and never appear.

**How it works:**
1. The only input is `sessionId`. `AgentActions.Calls` finds the household, or declines the request.
2. `DisputeStatusService.forHouseholds` runs once for every verified household. It reads in user mode, as the agent user.
3. Every request writes one log record, "Dispute status".

**What can go wrong:** The same declines as every action. An exception gives `FAILED` and a reference.

**How it's tested:** `GetDisputeStatusActionTest`:
- Each customer sees only their own billing disputes.
- An anonymous chat sees nothing.
- A failure gives a reference.
