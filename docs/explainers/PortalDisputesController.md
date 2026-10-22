# PortalDisputesController

**What it does:** Serves the portal's Disputes page and a dispute's own page: the household's disputes, the form for opening one, a single dispute with its evidence list, and opening a dispute.

**Why it exists:** ST-06, ST-12, S-14, NFR-07. A customer who thinks a bill is wrong should be able to say so and learn exactly what to send, without calling. Opening the dispute uses Phase 3's `DisputeIntakeService`, so Accord takes over exactly as it does for a dispute a rep opens: the SLA, the statement flag and the routing to Dispute Specialists.

**How it works:**
1. `getMyDisputes()` and `getDispute(caseId)` call `DisputeStatusService` for the logged-in household. A case ID from the address is looked for only among that household's billing disputes.
2. `getDisputeForm()` returns Accord's eight reasons, each with its evidence list, and the household's statements. A statement that already has an open dispute carries that dispute's number, so the page can point to it instead of offering it again.
3. `openDispute(statementId, reason, description)` builds a `DisputeIntakeService.Request` for the household and opens the dispute. The service checks the statement is the household's, refuses a second dispute on the same statement, removes card numbers from the description and saves the case under S-14.
4. A refusal the service reports as `FAILED`, such as a field the customer can't set, is logged through `PortalFailure.record`. The customer gets the reference; the detail is cleared from the result.

**What can go wrong:** Another household's statement is `NOT_FOUND`, and nothing is opened. A statement already in dispute gets `EXISTING_DISPUTE` with the open case's ID and number. A missing statement or an unknown reason is refused with its own reason code. An exception comes back as `FAILED` with a reference.

**How it's tested:** `PortalControllersTest`, as a real customer user:
- the household's disputes and one dispute's detail, and another household's dispute ID finds nothing
- the form lists the eight reasons, each with evidence, and names the open dispute on a statement already in dispute
- opening a dispute hands it to Accord: the household is stamped, the card number never reaches the case, the owner is Dispute Specialists and the statement is In Dispute
- another household's statement can't be disputed, and a second dispute points to the first
- a customer whose permission set lacks edit on `Dispute_Reason__c` is refused with `ACCESS_DENIED`, nothing is saved, and the log names the field (S-14)
- evidence files attach to the household's own dispute and not to another household's
