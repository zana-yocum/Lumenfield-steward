# TimelineCursor

**What it does:** Holds the timeline's place between pages: how many records of each kind earlier pages have shown, as JSON, such as `{"STATEMENT":12,"PAYMENT":8}`.

**Why it exists:** ST-15, NFR-02. The kinds interleave by date, so one OFFSET for the whole timeline can't work. Each kind needs its own count, so the next page asks each kind for the records after the ones already shown. Nothing is repeated or skipped, however the kinds fall.

**How it works:**
1. `parse` turns the previous page's cursor into counts by kind. Blank means the first page: no counts.
2. `format` turns counts into the cursor the component passes back.

**What can go wrong:** The cursor comes back from the browser, so it's treated as untrusted. Text that isn't JSON, JSON that isn't an object, or a count that isn't a whole number of zero or more makes `parse` return null. The controller then answers `INVALID_REQUEST`. A count can only skip records within the household the server already chose, so an edited cursor can't reach anything new. Each count is bound into the query as a value, never written into the query text.

**How it's tested:** `TimelineCursorTest`: a round trip, blank and null, and each kind of bad cursor. `CustomerTimelineControllerTest` refuses one end to end.
