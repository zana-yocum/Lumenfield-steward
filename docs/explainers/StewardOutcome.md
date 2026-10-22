# StewardOutcome

**What it does:** Defines the four outcome codes every Steward service returns (`COMPLETED`, `DECLINED_POLICY`, `HANDOFF`, `FAILED`), two reason codes every service shares (`NOT_FOUND`, `INVALID_REQUEST`), and the `Result` class every service result extends.

**Why it exists:** ST-11, GR-04, GR-06. Services return codes, never sentences. The agent puts them into words (GR-04), and supervisors see the same outcome on every log record (ST-11). With one shared set of codes, the agent, the log and the dashboard can't disagree about what happened.

**How it works:**
1. Every service result extends `StewardOutcome.Result`, which carries `outcome` and `reasonCode`, plus `reference` on a failure: the action log's number for the customer to quote (NFR-07). `setOutcome` sets the outcome and reason at once, so a result never ends up with a new outcome and an old reason.
2. `logLabel` turns an outcome code into the label stored in `Agent_Action_Log__c.Outcome__c`, such as "Declined by Policy". An unknown code returns null.
3. `describeErrors` turns a failed save's errors into one line, such as `REQUIRED_FIELD_MISSING: Required fields are missing: [Name]`, for the log's details. It's never shown to a customer (NFR-07).
4. `NOT_FOUND` is the answer both for a record that doesn't exist and for one that belongs to someone else, so a guessed ID confirms nothing (ST-12).

**What can go wrong:** A service could return a code that isn't one of the four. `logLabel` returns null, and `AgentActionLogger` saves the entry as Failed with "Unknown outcome code" in the details. The bug shows up on the dashboard instead of the entry going missing.

**How it's tested:** `StewardOutcomeTest`. Each of the four codes maps to its label, and unknown or null codes map to nothing. `describeErrors` is run on a real failed save (an account with no name) and includes the status code. A null error list gives an empty line. `setOutcome` sets both fields.
