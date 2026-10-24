# DisputeSummaryPrompt

**What it does:** Writes the data behind the Dispute Summary button: a billing dispute's reason, status and disputed statement, what the customer wrote, the commitments on the household, the evidence the reason needs against the files attached, any sales input, and the next SLA milestone.

**Why it exists:** ST-09, S-20. A dispute specialist should start from the facts that matter instead of gathering them from five places. Customers write dispute descriptions, and some will arrive through the agent, so the description is untrusted text by design.

**How it works:**
1. Prompt Builder calls `getPrompt` with the case from the page, as the person who clicked (request variable `Dispute`). `visibleDisputes` reads the case in user mode and keeps it only if it's a Billing Dispute. Anything else, including a case the person can't read, gets `NO_ACCESS`. `isVisibleDispute` is the same check, which `RepAssistantController` runs before any model does.
2. The description is read in its own query, so someone who can't read it still gets a summary, with "Not available to you." in its place. Specialists and supervisors can read it (S-22). It's quoted, up to 1,500 characters.
3. The disputed statement, the household's commitments, the files (names and dates from `ContentDocumentLink`, never contents), the newest five case comments and the next milestone (`SlaMilestones`) are each read once for all the cases.
4. Commitments are found through the disputed statement's household, because collections personas can't read `Case.AccountId`, and through Accord's DEF-07 field `Commitment__c.Account__c`. For a Promised Credit Not Applied dispute, a Recorded or Disputed commitment is marked `MAY_MATCH`: it could be the credit the customer means. The template lists those first. Every other commitment is marked `NOT_FLAGGED`, because in the first org check the model called an unmarked commitment a possible match when its type sounded related.
5. `EvidenceChecklist` writes the required and optional items for the reason, and the files attached.

**What can go wrong:** A part the person can't read says so instead of failing the summary. Case comments and file names are quoted like the description, because people typed them too. The summary never recommends an outcome: that's the template's rule 8, and the adversarial check in the org (`docs/agent-governance.md`) tests it.

**How it's tested:** `DisputeSummaryPromptTest` (5 tests). The facts come from the records; the description is quoted with its instruction to the AI intact, as content; a Recorded promotional credit is flagged as a possible match, an Expired coverage commitment is marked as not flagged, and another household's commitment is left out; the required items, file name, sales input and next milestone are there. With nothing attached, every required item is called missing. A default review, a user who can't read cases and a missing ID all get nothing. Requests get one answer each, in order, and file names keep one extension.
