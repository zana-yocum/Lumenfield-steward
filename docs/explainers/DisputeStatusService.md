# DisputeStatusService

**What it does:** Reads a household's billing disputes: each one's case number, status, reason, statement and opening date, newest first, and for a single dispute, the evidence its reason calls for, required items first.

**Why it exists:** ST-06, ST-12, S-16. A customer who opened a dispute needs to see where it stands and what's still needed, and the agent will answer the same question in Phase 6. The root cause, resolution notes and anything about the sales team are for Accord's specialists only, so they're never selected.

**How it works:**
1. `HouseholdScope` checks which requested households the caller can see. The rest are `NOT_FOUND`.
2. One user-mode query reads the visible households' Billing Dispute cases. For a customer, sharing decides what comes back: the `Customer_Household` sharing set matches cases on `Customer_Household__c`, which a before-save flow stamps only on Billing Dispute cases (S-16). Accord's Default Review cases on the same account are never stamped, so a customer can't see them, even by ID.
3. `getDispute(accountId, caseId)` looks for the case only among the household's billing disputes, then adds the evidence list from `DisputeEvidenceCatalog`, the same records behind Accord's intake, so the customer and the specialist work from one checklist.

**The flow:** `Case_BeforeSave_StampCustomerHousehold` copies `AccountId` onto `Customer_Household__c` when the record type is Billing Dispute, and clears it on any other case. It runs only when a case is created or its record type or account changes, the only times the answer can change.

**What can go wrong:** A case ID from another household, a default review or a case that doesn't exist all get the same `NOT_FOUND`, so a guessed ID confirms nothing. A missing household or case ID is `INVALID_REQUEST`.

**How it's tested:** `DisputeStatusServiceTest`, as real customer users. A customer sees their own disputes newest first, and never another household's dispute or a default review on their own account, by list or by ID. One dispute comes with its evidence, required first. The flow stamps the household on a dispute and clears it when the case becomes a default review. 200 households are read with two queries.
