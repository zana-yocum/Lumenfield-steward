# OpenDisputeAction

**What it does:** Opens the billing dispute the customer confirmed, on one of their own statements. It returns the case number and the evidence to send, required items first.

**Why it exists:** ST-06, S-14, GR-05, ST-12. A customer can dispute a bill at any hour, in their own words. Accord takes the dispute from there: its flows start the SLA clock and flag the statement, and its assignment rule routes the case to the dispute specialists. The agent reaches this action only after the customer has confirmed the statement and the reason (GR-05, in the agent's script).

**How it works:**
1. The inputs are `sessionId`, the statement ID, a reason value from Get Dispute Reasons, and an optional description in the customer's words.
2. `Calls.acceptsId` declines anything that isn't blank or a well-formed ID as `NOT_FOUND`.
3. `DisputeIntakeService.openDisputes` runs once for the whole call. It looks for the statement only in the session's household. It refuses a second open dispute on the same statement. It removes card numbers from the description before saving. It saves the case in system mode, with the caller's create access applied to every other field (S-14).
4. The whole call sits inside a savepoint. An exception rolls every case back, and every request in the call fails with a reference.
5. The log line has what was asked: "Open dispute: Payment Not Posted on statement a0X...". On `SAVE_FAILED`, it has the platform's message instead.

**What can go wrong:** Each of these opens nothing:
- `EXISTING_DISPUTE`: the open dispute's case number comes back.
- `INVALID_REASON`
- `STATEMENT_REQUIRED`
- `NOT_FOUND`
- `ACCESS_DENIED`: the caller can't create one of the case fields.
- `SAVE_FAILED`
- The usual declines.

**How it's tested:** `OpenDisputeActionTest`:
- A dispute opens on the customer's own statement, with its evidence list.
- Another household's statement opens nothing.
- Words in place of a statement ID open nothing.
- A chat with no customer behind it opens nothing.
- A failure opens nothing and gives a reference.

`AgentAccessTest` opens one as the agent user and reads the case number back.
