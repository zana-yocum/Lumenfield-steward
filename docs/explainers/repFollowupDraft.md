# repFollowupDraft

**What it does:** The Follow-up Draft button on a household. It asks for a draft of today's follow-up and opens it in the standard email composer, addressed and signed, for the rep to edit and send.

**Why it exists:** ST-10, S-21. The customer gets what was agreed in writing the same day, and the rep stays in control: nothing is sent from here.

**How it works:**
1. It's a screen quick action (`Account.Steward_Followup_Draft`). When it gets the household's ID, it calls `RepAssistantController.followupDraft`.
2. On success it opens the standard Email action (`Global.SendEmail`) on the household, with the subject, the body as HTML and the household as Related To filled in, and the To line when there's an address. Then it closes its own panel.
3. Otherwise it shows why there's no draft, in `repGeneratedText`.

**What can go wrong:** With no contact attempt logged today, the rep reads "Log today's contact attempt first, so the draft reflects what happened on the call." With no email address the rep can read, the To line is left for the rep. A failure shows the general message and opens nothing.

**How it's tested:** `repFollowupDraft.test.js` (5 tests): the composer opens with the address, subject, body and household, and the panel closes; no To line without an address; the log-first message (with `toBeAccessible`); a failure that opens nothing; Close.
