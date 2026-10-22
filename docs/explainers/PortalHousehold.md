# PortalHousehold

**What it does:** Answers one question for every portal page: whose household is this? It returns the account of the contact behind the logged-in user, or nothing for anyone who isn't a customer.

**Why it exists:** ST-12, S-07, GR-01. No portal controller takes an account ID from the browser. If one did, changing an ID in a request could point it at another household. The household comes from the login instead, the same way the agent will get it from the verified session in Phase 6.

**How it works:**
1. It reads `AccountId` from the logged-in user's own `User` record, in user mode. Salesforce sets that field when a contact is enabled as a customer user, so it's the contact's account: the household.
2. An internal user, such as an admin previewing the site in Experience Builder, has no contact, so the answer is null. Every service turns a null household into `INVALID_REQUEST`, and the page says it's for customers.

**What can go wrong:** Nothing a customer can change: the user record isn't theirs to edit. For the tests of every controller's failure path (NFR-07), a test can set a simulated exception that `current()` throws instead of answering. It's `@TestVisible` and always null outside a test.

**How it's tested:** `PortalHouseholdTest`. Two customer users each get their own household. An internal user and the pipeline user get none. `PortalControllersTest` uses the simulated failure to prove that every controller method turns an exception into a reference to quote.
