# PromptSection

**What it does:** Holds one titled part of a prompt's data: its lines, a sentence for when it has none, or "Not available to you." when the person asking can't read it.

**Why it exists:** ST-08, ST-09, S-20. "There are none" and "you can't see these" are different answers, and the model has to be told which one is true.

**How it works:**
1. Each section has a heading, a sentence for when it's empty, and a cap on its lines (null for none). `add` ignores lines past the cap, so a query can stay simple: sorted, then cut.
2. A loader calls `markUnavailable` when a user-mode query fails for lack of access. `toText` then writes the heading and `NOT_AVAILABLE`.
3. `isReadableAndEmpty` is true only for a readable section with no lines. The briefing's no-history sentence and the evidence checklist both depend on it, so an unreadable section is never mistaken for an empty one.

**What can go wrong:** Nothing on its own; it holds what its caller gives it.

**How it's tested:** Through `AccountBriefingPromptTest` and `DisputeSummaryPromptTest`: empty sections, capped lists, and six unavailable sections for a user who can't read them.
