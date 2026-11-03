# GetAccountSummaryAction

**What it does:** The agent's answer to "what do I owe?" It returns the logged-in customer's household figures:
- the balance and the past-due balance
- the oldest unpaid due date
- the next payment due
- every statement, newest first, with its payments
- any open promise to pay

**Why it exists:** ST-01, ST-12, GR-01, GR-04. Most service chats start with the balance. The figures come from `AccountSnapshotService`, the same service behind the portal's My account page, so the agent and the portal never disagree.

**How it works:**
1. The only input is `sessionId`, bound to `$Context.RoutableId`. There's no account input to misuse.
2. `AgentActions.Calls` finds the session's household, or declines the request.
3. `AccountSnapshotService.getSnapshots` runs once for every verified household. It reads in user mode, as the agent user.
4. The output always has the outcome, the reason code and the reference. On `COMPLETED` it also has the figures. A decline or a failure carries no figures at all.
5. Every request writes one log record, "Account summary".

**What can go wrong:**
- A chat with no logged-in customer is declined with `NOT_VERIFIED`, `SESSION_ENDED` or `WRONG_CHANNEL`.
- An exception gives `FAILED` and a reference the customer can quote. The error itself goes only to the log.

**How it's tested:** `GetAccountSummaryActionTest`:
- Two customers in two chats each get their own balances, to the cent.
- An anonymous chat gets nothing, and its log record says why.
- A failure gives a reference, not the error.

`AgentAccessTest` also runs it as the agent user.
