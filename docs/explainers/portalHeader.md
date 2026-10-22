# portalHeader

**What it does:** The header on every portal page: the Lumenfield Home Energy name, a link to each page, and Log out. The page you're on is marked for screen readers.

**Why it exists:** ST-01, ST-02, ST-06, NFR-05. Customers need to move between their account, statements, promises and disputes, and a screen-reader user needs to know where they are.

**How it works:**
1. It sits in the theme layout's header, so it's on every page without being added to each one.
2. Links are built with the navigation service, so they work wherever the site is published. The current page gets `aria-current="page"`, read from the current page reference. A statement's or a dispute's own page counts as Statements or Disputes.
3. Log out goes through the site's login page reference with the logout action, the way Experience Cloud sites log out.
4. The links sit in a `nav` labelled "Customer portal", and each is at least 24 pixels square (WCAG 2.2 target size).

**What can go wrong:** Nothing customer-specific: the header doesn't call the server.

**How it's tested:** `portalHeader.test.js`: every page link and Log out appear inside the labelled nav, the current page is marked, a dispute's own page marks Disputes, and the header passes the accessibility check.
