# ProductionReviewJob

**What it does:** Runs the production guarantee review (`ProductionGuaranteeService.review`) once a month, for every household whose agreement records an estimated production.

**Why it exists:** ST-14, S-29. The review has to happen on its own: nobody should have to remember to look for underproducing systems.

**How it works:**
1. An admin schedules it, and it runs as them, so reviews and credits are created with their access.
2. It finds every agreement with an estimate and reviews those households, for the 12 complete months before the day it runs.
3. A second run in the same month opens nothing new.

**What can go wrong:** Until Data 360 is set up there are no readings, so a run measures every household and opens nothing. It's scheduled once the readings exist (open items, Phase 8).

**How it's tested:** `ProductionReviewJobTest`: when the schedule fires, the two households with an estimate get reviews and the third doesn't; and a run reports what it measured and opened.
