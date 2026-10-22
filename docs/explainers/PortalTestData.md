# PortalTestData

**What it does:** Adds what the portal's tests need on top of `StewardTestData`'s households: customer users for their primary contacts, the role the households' owner needs first, and the internal Default Review case no customer may see.

**Why it exists:** NFR-03, S-04, S-18. From Phase 4, tests about access run as a real customer user instead of a stand-in. Customer users have rules of their own, so they get their own factory.

**How it works:**
1. `giveRunningUserARole()` gives the running user a role if it has none. Salesforce won't enable a contact as a customer user when the account's owner has no role, and the pipeline user has none. Tests call it before creating the households.
2. `createCustomers(households)` inserts one customer user per household's primary contact, on the Steward Customer Login profile, and assigns `PS_Steward_Customer`. Test customers use login licenses so the member licenses held by the demo customers are never needed by a test (S-18). Usernames and emails are on example.com and end in a sequence and a random token.
3. A second version takes another permission set, or none. `PortalControllersTest` uses it with a copy of `PS_Steward_Customer` that can't set the dispute reason, to prove S-14's field-level refusal.
4. `insertDefaultReview(household)` inserts the kind of case Accord's collections process opens, for the tests proving customers never see one.
5. Users are inserted in their own context (`System.runAs`), so creating a user doesn't collide with the test's other inserts.

**What can go wrong:** If Salesforce changes what a customer user needs, the tests fail at setup with Salesforce's own message, as they did when standard external profiles were switched off for user creation. That's what moved the tests to a custom profile.

**How it's tested:** By `PortalHouseholdTest`, `PortalControllersTest` and `DisputeStatusServiceTest`, which use it.
