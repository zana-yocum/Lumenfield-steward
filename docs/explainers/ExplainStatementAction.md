# ExplainStatementAction

**What it does:** The agent's answer to "why did my bill go up?" It compares a statement with the one before it and returns each reason, with its figures. The possible reasons:
- the annual escalator
- a posted credit
- an unpaid earlier statement
- no change
- the first statement
- a change the records can't explain

**Why it exists:** ST-03, GR-04, ST-12. The agent mustn't guess. When the records don't explain a change, `fullyExplained` is false, and the agent offers a dispute or a person.

**How it works:**
1. The inputs are `sessionId` and an optional `statementId` from Get Account Summary. Empty means the latest statement.
2. `Calls.acceptsId` declines anything that isn't blank or a well-formed ID as `NOT_FOUND`. "My last bill" is never looked up.
3. `StatementExplanationService.explain` runs once for the whole call. It looks for the statement only in the session's household. Another household's statement ID is `NOT_FOUND`, exactly like an ID that doesn't exist.
4. It reads in user mode, as the agent user. That includes the agreement's escalator rate, first due date and start date, which it reaches through the statement.
5. The log line says which statement was asked about: "Explain statement (latest)" or the ID.

**What can go wrong:**
- `NO_STATEMENTS` when the household has none yet.
- A chat with no logged-in customer is declined.
- An exception gives `FAILED` and a reference.

**How it's tested:** `ExplainStatementActionTest`:
- It explains the latest statement by default.
- It explains a statement it's given.
- Another household's statement is not found.
- Words in place of an ID aren't guessed at.
- A text-message session gets nothing (`WRONG_CHANNEL`).
- A failure gives a reference.

`AgentAccessTest` proves the agent user can read the agreement: the explanation comes back with the escalator.
