# GetCommitmentsAction

**What it does:** The agent's answer to "you promised me something when I signed." It returns what Lumenfield committed to at signing, such as covered payments or a welcome credit. For each commitment: its type, value, months covered, terms as the rep recorded them, and status.

**Why it exists:** ST-02, S-08, S-06, GR-04. Many disputes start with "the rep told me...". The agent can only repeat what's on the record, never promise more (S-06). Commitments sit under the opportunity, which the agent can't see and customers mustn't see. So `CommitmentReadService` reads the five customer-facing fields, and only for a household the caller can already see (S-08).

**How it works:**
1. The only input is `sessionId`. `AgentActions.Calls` finds the household, or declines the request.
2. `CommitmentReadService.forHouseholds` runs once for every verified household. The household check runs in user mode. Only the read of the commitments themselves is elevated.
3. When nothing was promised, the answer is `COMPLETED` with `NONE_RECORDED`, so the agent can say so plainly.
4. Every request writes one log record, "Commitments from signing".

**What can go wrong:** The same declines as every action (`NOT_VERIFIED`, `SESSION_ENDED`, `WRONG_CHANNEL`). An exception gives `FAILED` and a reference.

**How it's tested:** `GetCommitmentsActionTest`:
- Two customers each get only their own commitments, with one log record per request.
- An ended chat gets nothing (`SESSION_ENDED`).
- A failure gives a reference.

`AgentAccessTest` runs it as the agent user, who has no access to commitments or opportunities.
