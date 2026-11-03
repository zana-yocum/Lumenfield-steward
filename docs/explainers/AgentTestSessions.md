# AgentTestSessions

**What it does:** Stands in for the org's messaging records in tests. Each session is a well-formed `MessagingSession` ID that no record has, with the status, channel and logged-in user the test gives it.

**Why it exists:** S-07, S-23. A test can't open a real chat, because the platform creates messaging sessions when a conversation starts. Without a stand-in, nothing that depends on `AgentSession` could be tested.

**How it works:**
1. `chat(n, userId)` adds session *n*: an active Enhanced Chat with that customer logged in. A null user makes it an anonymous chat.
2. For any other kind of session, the test starts from `webChat(n, userId)`, changes what the test is about (the status, or the channel), and passes the result to `add`.
3. `install()` makes `AgentSession` read these sessions for the rest of the test. The customer users and households behind the sessions are real, from `PortalTestData` and `StewardTestData`, so `AgentSession`'s user checks run against real records.
4. `loads` counts lookups. A test can use it to prove that many sessions are looked up together, or that a malformed ID isn't looked up at all.

**What can go wrong:** Nothing outside a test. The class is `@IsTest`, so only test code can use it.

**How it's tested:** It's a tool the tests themselves use, and every agent test uses it.
