# StatementExplanationService

**What it does:** Explains a statement from the household's own records. It returns a list of reasons, each with its figures: how the amount due compares with the statement before (the annual escalator, no change, or a change the records don't explain), the posted credits on it, and the earlier statements still unpaid.

**Why it exists:** ST-03, ST-12, GR-04. "Why is my bill different?" is one of the most common reasons to call. The agent may only answer with facts from records: the service does the arithmetic and the model just puts it into words. When the records don't explain a change, the service says so, and the agent offers a dispute or a person instead of guessing.

**How it works:**
1. `HouseholdScope` gates the batch. Then two user-mode queries: the households' statements, newest first, each with its agreement's escalator rate and dates, and their posted credits. Three queries in all, for any number of requests.
2. The request names a statement, or leaves it blank for the latest. A statement that isn't in the household's list, including another household's, is `NOT_FOUND` (ST-12).
3. Reason one is always the amount comparison with the statement before it, worked out by `AmountDueComparison`.
4. Then each posted credit on the statement, with its type, amount and posted date. Draft, Pending Approval and Rejected credits are never read, so the agent can't tell a customer about money that may not come.
5. Then each earlier statement that still has a balance and isn't written off.
6. `fullyExplained` is false if any reason is `UNEXPLAINED_CHANGE`. The result's reason code says so too, which is the agent's cue to offer a dispute or a person.

**What can go wrong:** A household with no statements gets `NO_STATEMENTS`. A statement with nothing before it gets `FIRST_STATEMENT`. An increase that isn't the escalator, or a decrease, is `UNEXPLAINED_CHANGE`: the service reports what changed, and doesn't invent why.

**How it's tested:** `StatementExplanationServiceTest`, with known answers. The escalator household pays $120.00 until its agreement's first anniversary, then $123.48 (2.90%). The test expects an `ESCALATOR` reason of exactly $3.48 at that anniversary. Its latest statement also has a $40 posted credit plus a draft, a pending and a rejected credit. Only the $40 is named, and Accord's flow has applied only the $40, leaving a balance of $83.48. One earlier statement is unpaid ($120.00), and the paid one is left out. Other households cover an unexplained $15.00 increase, a rate-sized increase that isn't at an anniversary (still unexplained), no change, a first statement, no statements, a chosen earlier statement, another household's statement, and a user who can't see the household. 200 households are explained with three queries.
