# HouseholdBriefing

**What it does:** Holds one household's briefing data while `AccountBriefingPrompt` gathers it, then writes it out in the order the template reads it.

**Why it exists:** ST-08, S-20. It keeps the briefing's shape in one place: what comes first, how many of each, and when to say there's nothing to discuss.

**How it works:**
1. The household's own facts come first, then six `PromptSection`s: unpaid statements (up to 6), last payments (3), promises (5), open disputes, commitments, and contact attempts (5).
2. `hasNoHistory` is true only when nothing is past due and the promise, dispute, commitment and attempt sections are all readable and empty. Then `toText` adds `NO_HISTORY`, and the template writes a sentence instead of six empty headings (ST-08).
3. `section(name)` lets a loader mark its own section unavailable by name.

**What can go wrong:** Nothing on its own; it holds what the loaders give it.

**How it's tested:** Through `AccountBriefingPromptTest`: the no-history sentence for the quiet household, never for one with history, and never when the sections can't be read.
