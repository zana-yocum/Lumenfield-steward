# TimelineReader

**What it does:** Reads one household's timeline for `CustomerTimelineController`: one query per kind of event, all in user mode, merged into a single page, newest first.

**Why it exists:** ST-15, ST-12, NFR-01. ST-15 says a field the rep can't read doesn't appear. A plain `WITH USER_MODE` query fails outright if it names one such field. So the reader asks first and names only what the person can read: one hidden field leaves one gap, not a broken page.

**How it works:**
1. When it's created, it describes the seven objects involved once, with deferred field describes.
2. A kind (`TimelineKind`) is offered only when the person can read its object, the field that ties it to the household, its date, and any field its query filters on. A path such as `Opportunity__r.CloseDate` counts only when the lookup, the object it reaches and the field are all readable.
3. For each kind asked for, it selects `Id`, the record's number and the date, plus each fact field the person can read. It runs the query with `Database.queryWithBinds` in `AccessLevel.USER_MODE`, binding every value: the household, the condition value, the row limit and the offset. The query text holds only constant field paths from `TimelineKind`, so nothing a caller sends ever becomes SOQL.
4. Each kind asks for one more row than a page holds. The extra row says whether that kind has more.
5. It merges the kinds' lists: it repeatedly takes the event with the latest date. On the same date, the kind that comes first in display order goes first. This works because every kind's query is ordered by the same date that places its events.
6. It records how many of each kind the page took, adds those to the earlier counts, and returns them as the next cursor (`TimelineCursor`).

**What can go wrong:**
- A kind the person can't fully read isn't offered at all, rather than failing the page.
- SOQL can't skip more than 2,000 rows. A kind that reaches that limit stops paging. Its count stays in the cursor, so it never starts again from the top while the other kinds carry on.
- A record with no date sorts last, both in its query (`NULLS LAST`) and in the merge.

**How it's tested:** Through `CustomerTimelineControllerTest`: every kind in order, paging 199 statements with nothing repeated or skipped, the offset limit with a one-event page, and a customer whose access leaves out one field.
