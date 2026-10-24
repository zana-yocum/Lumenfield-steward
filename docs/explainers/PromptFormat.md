# PromptFormat

**What it does:** Writes amounts, dates, times, checkboxes and missing values one fixed way for a prompt, and fences text a person typed.

**Why it exists:** ST-08 to ST-10, ST-17, S-20. The templates tell the model to copy every figure exactly, so each figure must already be written the way a rep should read it, whatever the user's locale. And text a person typed must never pass for instructions.

**How it works:**
1. `money` writes `$1,234.50`, or `-$12.00` for a credit, rounding half up to the cent. `day` writes `Oct 23, 2026` from its own list of month names, so every locale gets the same text. `moment` adds the time and zone in the reader's own time zone, such as `4:00 PM EDT`.
2. A missing value reads "not recorded". The `…Or` versions (`moneyOr`, `dayOr`, `momentOr`) write given words instead, such as "none" or "no".
3. `quoted(text, max)` removes card numbers, email addresses and phone numbers (`SensitiveText.redactForPrompt`), puts the text on one line, swaps `<` and `>` for `‹` and `›` so it can't close its own tag, cuts it at the limit with " [shortened]", and puts it between `<quoted>` and `</quoted>`. Blank text is quoted as "(blank)".
4. `inOrder` gives Prompt Builder one text per request, in the order it asked, with a fallback for a request with no record or a record the person can't see.

**What can go wrong:** Nothing a caller can cause: every method accepts null.

**How it's tested:** `PromptFormatTest` (7 tests): amounts from zero to millions, a credit and half a cent; dates at both ends of the year; a moment in the reader's zone; checkboxes and blanks; quoted text holding an email address, a phone number, a card number and a fake closing tag; cutting to length; blank text.
