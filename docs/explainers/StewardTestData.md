# StewardTestData

**What it does:** Builds the invented households every Steward test runs against: a Residential Agreement account, its primary contact and its agreement, plus whatever statements, payments, credits, promises, deals, commitments, entitlements and disputes a test needs. It also creates the test user who can't see anything.

**Why it exists:** NFR-03. Tests that prove something need data whose right answers are known in advance, and no test may read the org's own data (no `SeeAllData`). One factory keeps every test's data shaped the way Accord's rules expect, so a test fails because the code is wrong, not because the data broke a validation rule.

**How it works:**
1. `createHouseholds(count, status)` inserts accounts, then contacts with the Primary role, then agreements. The order matters. Accord's `Contact_AfterSave_StampPrimaryContact` flow makes each contact its account's primary contact, and `VR_Account_PrimaryContactRequired` blocks any later account update without one, including the roll-up recalculations that statements cause.
2. Every agreement's first payment was due on the first of the month 13 months ago, at $120.00 a month with a 2.90% escalator. So its first anniversary is always the first of last month, whatever day the tests run. That's how the escalator test has a known answer of exactly $123.48.
3. The other builders (`statement`, `payment`, `credit`, `promise`, `deal`, `commitment`, `entitlement`) return records without inserting them, so a test can insert many in one statement. Each one fills in what Accord's rules need: a statement date 20 days before the due date, a reason on a rejected credit, an open deal so Accord's Closed Won rule stays out of it.
4. Names and emails end in a sequence number plus a random token, so households a test method adds never collide with those from the test's setup.
5. `addKnownAnswerHistory` gives a household the history the snapshot and briefing tests check: four $120.00 statements (one paid, two past due, one due in two weeks), $120.00 and $50.00 paid, and a $190.00 promise ten days out. So $310.00 owed and $190.00 past due. `existingHouseholds` reads back the households a test's setup created, in the order they were created, each with its contact's name and email, so a test can assert that none of them reached a prompt.
6. `createUserWithoutAccess` inserts a Standard Platform User: it can read accounts only where sharing allows and has no access to Accord's objects or to cases. The insert runs in its own context, so creating a user doesn't collide with the test's other inserts. `shareRead` then gives that user read access to one account, for the tests where sharing has to decide.

**What can go wrong:** If Accord changes a rule the data depends on, such as a new required field, the tests fail at setup with Accord's own error message. That's the right place to find out.

**How it's tested:** By every Steward test class that uses it. Its known answers are asserted to the cent in `AccountSnapshotServiceTest`, `AccountBriefingPromptTest`, `StatementExplanationServiceTest` and `PaymentArrangementServiceTest`.
