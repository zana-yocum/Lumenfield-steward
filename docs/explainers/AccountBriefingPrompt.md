# AccountBriefingPrompt

**What it does:** Writes the data behind the Briefing button: one household's balances and status, its unpaid statements, last payments, promises, open disputes with their next SLA milestone, commitments from signing and recent contact attempts. Each is a labelled line the model copies into the briefing.

**Why it exists:** ST-08, S-20. A rep needs the account's story before the phone rings, with every figure exactly as recorded and nothing the rep isn't allowed to see.

**How it works:**
1. Prompt Builder calls `getPrompt` with the household from the page, as the person who clicked Briefing. The request's variable is named `Household`, exactly like the template's input; that's how Prompt Builder matches them (no `CapabilityType`, S-20).
2. `HouseholdScope.visibleHouseholds` keeps only Residential Agreement accounts the person can see. Anything else gets `NO_ACCESS`, and the template answers "This household isn't available to you."
3. Seven loaders fill a `HouseholdBriefing` for each household, each with one user-mode query however many households there are: the account's own fields, unpaid statements, payments, promises (open, or due in the last 90 days), open billing disputes with their next milestone (`SlaMilestones`), commitments, and contact attempts from the last 30 days.
4. Every loader but the first catches the error a user-mode query raises when the person can't read an object or field, and marks its section "Not available to you." The rest of the briefing still runs.
5. The payment query asks for `Method__c` only when the person can read it, so a rep's briefing never holds a payment method and a supervisor's can (ST-08). The processor reference is never queried.
6. `RecordLines` writes each record's line and `PromptFormat` writes the amounts, dates and quoted text, so a record reads the same way in a briefing and a dispute summary.

**What can go wrong:** A household the person can't see gets `NO_ACCESS`, the same as one that doesn't exist. A section the person can't read says so. Someone who can see the household but not one of its own fields gets the platform's error, and the button shows "couldn't write this" with the detail; no Accord persona is in that position. A household with nothing past due and no promises, disputes, commitments or attempts gets the no-history sentence, but only when all of those could be read.

**How it's tested:** `AccountBriefingPromptTest` (8 tests), on the snapshot test's known-answer household ($310.00 owed, $190.00 past due). Every figure is compared with the records. The payment method appears only for someone who can read it, and as the running user's own access says when nothing overrides it. No names, email addresses or phone numbers appear, including ones typed in notes. A quiet household gets the no-history sentence. A dispute shows its next milestone. A user who can't see the household gets `NO_ACCESS`; a user who can see it but none of its related records gets six "Not available to you." and no no-history sentence. Requests get one answer each, in order.
