# repGeneratedText

**What it does:** Shows what the assistant wrote: a spinner while it writes, then the text with a reminder to check it against the record, or why there's nothing.

**Why it exists:** ST-08, ST-09, S-21. The Briefing and Dispute Summary buttons show the same kind of result, and the follow-up shows the same messages.

**How it works:**
1. Four public properties: `loading`, `text`, `message` and `detail`. The parent sets them; this only shows them.
2. The text appears in a labelled region as plain text, with the model's line breaks kept (`white-space: pre-line`). It's never rendered as HTML, so nothing a customer typed can turn into a link or markup in the console.
3. Below the text: "Written by AI from this record's data. Check it against the record before you rely on it."
4. A message appears as a warning with `role="status"`, and the detail in smaller text underneath, only when there is one.

**What can go wrong:** Nothing on its own; it shows what it's given.

**How it's tested:** `repGeneratedText.test.js` (5 tests): the spinner; the text with its reminder; markup in the text shown as text; a message with and without detail. The loading, text and message states each pass `toBeAccessible` (NFR-05).
