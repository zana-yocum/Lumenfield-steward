# CustomerTimelineController

**What it does:** Serves the customer timeline a page at a time: one household's statements, payments, promises to pay, billing disputes, credits and commitments, newest first, 20 events to a page.

**Why it exists:** ST-15, ST-12, NFR-06, NFR-07. A rep should see the story of an account in one place instead of six related lists, and a customer should see their own history on the portal. The same component serves both, so the controller has to give each person exactly what their own access allows, and nothing about anyone else's household.

**How it works:**
1. It works out the household. On the portal it's always the logged-in customer's own (`PortalHousehold`), whatever the page passes. In the console it's the record page's account, if `HouseholdScope` says the user can see it as a household.
2. It reads the cursor (`TimelineCursor`): how many of each kind earlier pages showed. None means the first page.
3. `TimelineReader` fills the page in user mode: the kinds this person can read (`availableKinds`), the next events of the kinds asked for, and the cursor for the page after, or null when there's nothing more.
4. It returns a `TimelinePage`, which carries Steward's usual outcome and reason codes (`StewardOutcome`).

Each `TimelineEvent` has the kind, record ID, date, the record's number, and up to five facts: amount, balance, due date, status and detail (a dispute's reason, or a credit's or commitment's type). A fact the person can't read is null.

**What can go wrong:**
- An account the user can't see, or one that isn't a household: `DECLINED_POLICY` / `NOT_FOUND`, the same answer for both (S-07).
- A cursor that isn't one, such as edited text: `DECLINED_POLICY` / `INVALID_REQUEST`.
- Anything unexpected: `FAILED` with a reference to quote. `PortalFailure` writes the details to the log, and the person never sees the error (NFR-07).

**How it's tested:** `CustomerTimelineControllerTest`, against two invented households:
- Every kind arrives newest first on the right dates. On the same day, kinds keep their display order. A credit still in draft isn't on the timeline.
- 199 statements page through in tens without a repeat or a gap. A kind that reaches SOQL's offset limit keeps its place in the cursor.
- The filter returns only the kinds asked for and still offers every kind.
- An outsider gets `NOT_FOUND`. A customer gets their own household whatever ID the page passes, and no credits or commitments, which customers can't read.
- A customer whose access leaves out the statement balance gets statements without balances.
- A bad cursor is refused, and a failure gives a reference, not the error.
