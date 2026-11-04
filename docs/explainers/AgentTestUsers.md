# AgentTestUsers

**What it does:** Creates the service agent's user for tests that run actions the way the agent will. The user is on the Einstein Agent User profile, with only `PS_Steward_Agent` and membership of the Steward Agent group. The group gets, by hand, exactly what its two sharing rules give it.

**Why it exists:** S-01, ST-12, NFR-03. `AgentAccessTest` and `AgentPaymentAccessTest` both need the same user. The payment test makes it in its setup, because Salesforce refuses a callout after a save in the same test.

**How it works:**
1. `createAgentUser(households)` shares the households with the group, as the rules do: Edit on accounts with Read on their cases, and Read on agreements.
2. It then inserts the user, the permission set assignment and the group membership in their own context, because they're setup records.
3. `existingAgentUser()` finds the user a test's setup created.

**What can go wrong:** A check-only deployment doesn't apply the sharing rules it brings, which is why the shares are made by hand. The rules themselves are checked in the org after each release.

**How it's tested:** By the two access tests that use it.
