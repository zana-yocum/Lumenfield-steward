# portalShared

**What it does:** The code every portal component shares: the pages they link to, the outcome codes the server returns, the portal's text, and the words a customer sees when something isn't there or goes wrong. It has no screen of its own.

**Why it exists:** ST-01, ST-02, ST-06, NFR-05, NFR-07, ST-18. Ten components show the same kinds of things: money, dates, links between pages, and problems. One module keeps them saying it the same way, and keeps every customer-facing message in one place.

**How it works:**
1. `PAGES` names the six pages by their routes' API names. `namedPage(name)` builds a link to one. `recordPage(recordId, name)` builds a link to a statement's or a dispute's own page with the record's ID in the address (`?recordId=…`), and `recordIdFrom(pageRef)` reads it back (S-17). `LOGOUT_PAGE` logs out through the site's own login page reference.
2. `LABELS` holds every customer-facing word, imported from the `Steward_Portal_*` custom labels in `labels.js`. `format(label, …values)` fills a label's `{0}`, `{1}` placeholders, so word order can change in a translation (ST-18).
3. `problemMessage(result, notFound)` turns a result that isn't a success into one or two sentences. A failure with a reference says "quote reference AAL-…"; a user with no household is told the portal is for customers; "not found" uses the page's own words. It never shows a reason code or an error.
4. `formatMoney` writes amounts to the cent in US dollars. `formatDate` reads the server's `YYYY-MM-DD` as UTC, so a date never moves a day in the customer's time zone.

**What can go wrong:** A result with no answer at all, or a reason code the portal doesn't know, gets the plain "Please try again later." A label with a missing value leaves that spot blank rather than printing "undefined".

**How it's tested:** `portalShared.test.js` (12 tests): every branch of `problemMessage`, including that a failure's details never appear; `format` with filled and missing values; money and dates; and the page references, including the record ID's round trip through the address.
