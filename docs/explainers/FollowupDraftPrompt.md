# FollowupDraftPrompt

**What it does:** Writes the data behind the Follow-up Draft button: today's date, the outcome of the contact attempt the person logged on the household today, the promise recorded with it when the outcome was Promise Made, the past-due balance, and whether Do Not Contact is set.

**Why it exists:** ST-10, S-20. The draft must reflect what actually happened on the call, with the promise's amount and date taken from the Promise to Pay record, and nothing that identifies the customer.

**How it works:**
1. `latestAttemptToday` finds the newest Task with an outcome that the running user created on the household today, in user mode. `RepAssistantController` asks it first: no attempt, no draft (ST-10).
2. `build` writes the lines for each household the person can see. For Promise Made, it adds the newest promise the same person recorded on the household today: Accord's Log Contact Attempt flow saves the attempt and the promise from the same screen, so that's the call's promise.
3. The rep's notes from the call aren't read at all, because the draft goes to the customer.

**What can go wrong:** Someone who can't read contact outcomes has no attempt to ground a draft in, so they're asked to log one. A Promise Made with no promise found says "none found.", and the template thanks the customer without naming an amount.

**How it's tested:** `FollowupDraftPromptTest` (5 tests). The promise line comes from its record, with the status Accord's flow gave it; other outcomes have no promise line; an attempt logged yesterday doesn't count; a user who can't see the household gets nothing, and no attempt; requests get one answer each, in order. The contact's name and email address never appear.
