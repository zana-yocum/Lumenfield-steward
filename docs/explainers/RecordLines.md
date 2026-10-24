# RecordLines

**What it does:** Writes one line for each kind of record the rep assistant sends to a model: an unpaid statement, a disputed statement in full, a payment, a promise, an open dispute, a commitment and a contact attempt.

**Why it exists:** ST-08, ST-09, S-20. The briefing and the dispute summary describe some of the same records, and should describe them the same way.

**How it works:**
1. A promise shows when it was made, the amount, the date and the status; then its grace date while it's open (Active or Pending Approval), or what was received once it's been judged.
2. A payment shows its method only if the query read it (`getPopulatedFieldsAsMap`). The method is queried only for someone who can read it, so the line never guesses.
3. A commitment shows its type, its value ("none (not a dollar amount)" when it has none), the months covered ("1 month", "3 months"), its status, an optional note such as the summary's match flag, and its terms as quoted text, up to 600 characters.
4. A contact attempt shows the day it was logged, its outcome, and the rep's notes as quoted text, up to 400 characters.

**What can go wrong:** A missing value reads "not recorded", and a missing disputed statement reads "None recorded."

**How it's tested:** `RecordLinesTest` (4 tests), with records built in memory so no automation runs: a broken promise with money received and a kept one without; a payment with and without its method; a missing statement; an attempt's notes quoted without the phone number in them; a commitment with no dollar value. The briefing and summary tests check the same lines on saved records.
