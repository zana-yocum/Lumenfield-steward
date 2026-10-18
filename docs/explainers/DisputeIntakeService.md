# DisputeIntakeService

**What it does:** Opens a Billing Dispute case on one of the household's statements, then returns the case number and the evidence to send for the reason, required items first.

**Why it exists:** ST-06, ST-12, GR-02. Disputes stall when the customer doesn't know what to send. The service creates the case exactly as a rep would, so Accord takes over from the save, and it gives the customer the same evidence checklist the specialist works from.

**How it works:**
1. For the batch, it reads in user mode: the visible households and their primary contacts, the named statements (only those in a visible household), and any open Billing Dispute already on those statements.
2. Each request is checked in order: complete, household in reach, a statement named, the statement in that household (another household's statement is `NOT_FOUND`), and one of the eight reasons. The first failure is the answer.
3. A statement that already has an open dispute, or was claimed earlier in the same batch, gets `EXISTING_DISPUTE` with the existing case's number. No duplicate is created.
4. The case is built with the household, its primary contact, the statement and its agreement, the reason, origin Web, a subject, and the customer's description with card numbers removed and cut to fit.
5. Assignment rules don't run on cases Apex creates unless asked, so the service asks, through `DMLOptions`. Accord's `Accord Case Routing` rule then puts the case in the Dispute Specialists queue.
6. The save runs in system mode, the one exception here (S-14). `Case.AccountId` is read-only in every profile and permission set in the org, and Accord's entitlement flow needs the account when the case is created. Before saving, `blockedFields` applies the caller's own create access to the Case object and every other field. A caller who couldn't create the case themselves gets `ACCESS_DENIED`, and nothing is saved.
7. Accord's flows run on the save: the SLA entitlement is stamped and the statement is flagged In Dispute. The case number is read back in user mode, and the evidence list comes from `DisputeEvidenceCatalog`.

**What can go wrong:** Declines are `DECLINED_POLICY` with the reason (`STATEMENT_REQUIRED`, `INVALID_REASON`, `EXISTING_DISPUTE`, `NOT_FOUND`). A save that fails is `FAILED` with the platform's message in `failureDetail`, for the log only. Once the case is in the queue, the caller needs read access through sharing to see its number. That's set up for the agent user in Phase 6.

**How it's tested:** `DisputeIntakeServiceTest`. One test opens a dispute and checks what Accord did: the account, contact, record type, statement, reason and origin are set; the entitlement is stamped; the owner is the Dispute Specialists queue; the statement is In Dispute. The evidence comes back with required items first. A second dispute on the same statement points to the first, and two in one batch create one case. Another household's statement, a household the caller can't see, a missing statement and an unknown reason are each refused. A card number never reaches the case. `blockedFields` passes the admin and refuses a user with no Case access. 200 disputes open in one call.
