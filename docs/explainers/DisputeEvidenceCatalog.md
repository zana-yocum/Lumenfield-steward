# DisputeEvidenceCatalog

**What it does:** Lists the eight dispute reasons and, for each one, the evidence a customer needs to send, required items first.

**Why it exists:** ST-06, ST-09. The reasons come from Accord's `Case.Dispute_Reason__c` picklist and the evidence from Accord's 16 `Dispute_Evidence_Requirement__mdt` records, the same checklist the dispute specialists use. When a specialist's checklist changes, the agent's changes with it.

**How it works:**
1. `getReasons` returns each active picklist value with its label and evidence list, in the order Accord lists them. The agent offers these to the customer.
2. `evidenceFor(reason)` returns one reason's evidence. Required items come first, then each group in the order of the records' developer names, since the records have no sort field.
3. `isReason(value)` checks a value against the active picklist values. `DisputeIntakeService` uses it before creating a case.
4. The records are read once per transaction with `getAll()`, which doesn't count against query limits. Each call returns a new list, so a caller can't change the cached copy.

**What can go wrong:** An unknown reason returns an empty evidence list and fails `isReason`, so no case is created for it. A reason with no evidence records would return an empty list. All eight have records today, and the test fails if one stops matching.

**How it's tested:** `DisputeEvidenceCatalogTest`. There are eight reasons, each with exactly as many items as Accord has records for it, each with a label, and required items always first. For Promised Credit Not Applied, the signed agreement (required) comes before the sales rep's confirmation (optional). `isReason` accepts a real reason and refuses "Just credit my account" and null, and an unknown reason has no evidence list. Clearing a returned list doesn't change the next answer.
