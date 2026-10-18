# SensitiveText

**What it does:** Replaces anything shaped like a card number with `[card number removed]` before free text is saved.

**Why it exists:** ST-05, ST-11, S-06. Customers type card numbers into chats, whatever the instructions say. That text can reach two places Steward writes: a dispute's description and the agent log's details. Neither should ever hold a card number, and supervisors read the log.

**How it works:**
1. One regular expression matches 13 to 19 digits, optionally split by single spaces or hyphens. That covers the usual ways a card number is written: `4111111111111111`, `4111 1111 1111 1111`, `4111-1111-1111-1111`, and 15-digit and 19-digit cards.
2. A match can't start or end in the middle of an unbroken run of digits, so part of a longer number, like a 25-digit reference, isn't removed.
3. `redact` replaces every match and returns the rest of the text unchanged.

**What can go wrong:** It doesn't run a checksum (Luhn), so a 16-digit number that isn't a card would also be removed, and so would part of a long number typed in groups of four. For a log, removing too much is the safe way to be wrong. A card number written with other separators, like dots or slashes, wouldn't match. The agent's instructions in Phase 6 also tell customers not to share card details, and Phase 6 checks whether the chat transcript itself can mask them (ST-05).

**How it's tested:** `SensitiveTextTest`. Five card formats are removed inside a sentence. A phone number, an amount, a date, a statement number and an 8-digit account number are left alone. Null, empty and all-space text comes back unchanged.
