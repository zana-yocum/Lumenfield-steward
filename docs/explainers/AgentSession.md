# AgentSession

**What it does:** Answers one question for every agent action: whose household is this conversation for? Given the messaging session's ID, it returns the account of the customer the platform logged in to the chat. If there isn't one, it returns no household and the reason why.

**Why it exists:** ST-12, S-07, S-23, GR-01. The model must never choose whose data to read. If an action took an account ID from the conversation, a customer could type someone else's. So no action has an account input. Each one takes the session ID instead. The agent binds that input to `$Context.RoutableId`, the conversation's own ID, which the platform sets, so the model can't fill it. From there this class follows only links the platform sets. It's the agent's version of `PortalHousehold`.

**How it works:**
1. The ID must be a well-formed `MessagingSession` ID. Anything else gets no household and isn't even looked up: a blank, words, or an account ID.
2. It reads three things about the session: its status, its channel type, and its messaging user's `AuthenticatedEndUserId`. That last field is the portal user the platform verified when the customer opened the chat from the logged-in site. No API call, rep or model can set it.
3. Three checks, in order:
   - The channel must be Enhanced Chat (`EmbeddedMessaging`), the portal's web chat. Otherwise it's `WRONG_CHANNEL`.
   - The session must not have ended. Ended, Inactive and Error are `SESSION_ENDED`.
   - The authenticated user must be an active customer user (Customer Community or Customer Community Plus) with a contact and an account. Anyone else is `NOT_VERIFIED`. That covers an anonymous chat, an employee, and a customer whose login was turned off.
4. The household is that user's `AccountId`: the account of the contact behind the login.
5. It takes two queries, however many sessions there are.
6. These reads run in an inner `Elevated` class, without sharing and in system mode (S-23). The agent user has no access to messaging records or to customers' user records, and shouldn't need any. The reads start from an ID the model never chooses, follow links only the platform sets, and return nothing but an account ID. Everything read after that is read in user mode, as the agent user, through the services.

**What can go wrong:** Whenever no logged-in customer is found, the result is the same: no household, a reason code, and nothing read. The action declines with that code, and the agent can offer a person. A test can't open a real chat, so tests swap in `AgentTestSessions` as the session source. The `source` field is `@TestVisible`, and outside a test it's always the org's own records.

**How it's tested:** `AgentSessionTest`:
- Two customers' chats each resolve to their own household, in one lookup.
- Each of these gets no household and the right reason: an anonymous chat, an employee who is logged in, a deactivated customer, an ended chat, and a text-message session.
- Blank IDs, malformed IDs and other objects' IDs are refused without a lookup.
- A session that doesn't exist has no household.
- A `MessagingSession` record built in memory maps to the right facts, including a session with no messaging user.

The platform side, a real chat from the logged-in portal, is checked once the chat is set up (open items).
