# RecordHandoffAction

**What it does:** Records that the agent is handing the conversation to a person. The record holds the reason code that led there and a one- or two-sentence summary for the person taking over. It returns the log record's number.

**Why it exists:** ST-07, ST-11. A supervisor needs to see what the agent couldn't do, and the person picking up the chat needs to see why it came to them. The agent calls this action right before every transfer.

**How it works:**
1. The inputs are `sessionId`, the reason code from the action that led here, and the summary.
2. The reason code is kept only if it looks like one: capital letters and underscores, at most 40 characters. Anything else is recorded as `CUSTOMER_ASKED`, so free text from the model never becomes a reason code.
3. A chat with no logged-in customer is recorded too, because a person is exactly who should take it. Its log record has no household.
4. Card numbers are removed from the summary before it's saved (`AgentActionLogger`).
5. Every handoff gets its log number as the reference, not only failures.

**What can go wrong:** A summary that can't be saved still hands off. It just has no reference.

**How it's tested:** `RecordHandoffActionTest`:
- A handoff is recorded with its reason.
- A chat with no customer behind it is still handed off.
- Only text shaped like a reason code is kept as one.

`AgentAccessTest` records one as the agent user.
