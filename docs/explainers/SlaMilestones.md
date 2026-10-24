# SlaMilestones

**What it does:** Finds each billing dispute's next open SLA milestone and writes it as, for example, "Resolve Dispute, due Oct 22, 2026, 6:00 PM EDT (missed)."

**Why it exists:** ST-08, ST-09. The briefing and the summary both report a dispute's SLA status, and a missed milestone has to be said plainly.

**How it works:**
1. One user-mode query reads the open milestones on all the cases, soonest first, and keeps the first for each case.
2. The due time is in the reader's time zone, with the zone named (`PromptFormat.moment`).
3. A case with no open milestone reads "none open." Someone who can't read milestones gets "not available to you." for every case, instead of a failed summary.

**What can go wrong:** A dispute opened before its household had an entitlement has no milestones, and reads "none open." Accord's flow stamps the household's SLA entitlement on each new dispute.

**How it's tested:** `SlaMilestonesTest` (3 tests), on a dispute that Accord gave the Billing Dispute SLA: the soonest milestone, with its time and missed flag; "none open." for a record without milestones, and nothing back for an empty request; "not available to you." for a user who can't read cases.
