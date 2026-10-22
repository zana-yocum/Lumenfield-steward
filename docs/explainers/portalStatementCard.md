# portalStatementCard

**What it does:** One statement as a customer sees it: statement date, due date, amount due, paid, credits applied, balance and status, the payments made against it (date and amount only), and a link to its dispute when one is open.

**Why it exists:** ST-01. The customer sees the same amounts a rep does, and a statement that's in dispute says so and leads to the dispute.

**How it works:**
1. The Statements page passes in a statement and asks for the number to link to the statement's own page. The statement's own page passes it in with the title hidden, because its heading already names the statement.
2. Payments show only their date and amount. The payment method and processor reference are never sent by the server (ST-01).
3. Headings stay in order: on the Statements page "Payments" is a level-3 heading under the statement's level-2 title; on the statement's own page it's level 2 under the page's title.

**What can go wrong:** A statement with no payments says so. It doesn't call the server, so it has no error states of its own.

**How it's tested:** `portalStatementCard.test.js`: the amounts, status and each payment's date and amount only; the link to an open dispute; and the heading levels on the statement's own page, each passing the accessibility check.
