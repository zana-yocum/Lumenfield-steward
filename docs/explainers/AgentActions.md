# AgentActions and AgentActions.Calls

**What it does:** Everything the nine agent actions do around their service call, written once. `Calls` holds one call's requests, in order, and takes each one from its session to its log record.

**Why it exists:** ST-11, ST-12, GR-01, GR-06, NFR-07. Every action has to follow the same rules. It declines a chat with no logged-in customer before reading anything. It never shows a customer an error. It logs every request, including the ones it declined and the ones that failed. Written nine times, those rules would drift apart. With `Calls`, each action class is only its service call and the shape of its answer.

**How it works:**
1. `new AgentActions.Calls(action, sessionIds)` resolves every request's session through `AgentSession`, in two queries.
2. `begin(i, blank, detail)` starts request *i*. It takes an empty result of the action's own kind and a short line for the log. If the session has no verified household, the request is declined there with its reason code (`NOT_VERIFIED`, `SESSION_ENDED` or `WRONG_CHANNEL`), and nothing is read for it. `begin` returns whether the request goes on.
3. `acceptsId(i, value)` checks a record ID the model passed:
   - A blank goes on. The service decides what blank means, such as "the latest statement".
   - A well-formed ID goes on, and the service looks for it only in the household (ST-12).
   - Anything else, such as "last month's bill", is declined `NOT_FOUND`. Nothing is read and nothing is guessed.
4. The action calls its service once, for every request still waiting. A service that reads by household gets them from `households()`. The action then hands the answers back with `serve(i, result)` or `serveAll(sent, results)`. `logFailureDetail` puts the service's own failure message in the log line, such as the platform's message when a save fails.
5. If the service call throws, `fail(error)` fails every request that reached the service. That includes one the service had already answered, because the write actions roll the whole call back. Each request gets its empty result back, marked `FAILED` with `UNEXPECTED_ERROR`. The error's type and message go only to the log.
6. `finish()` logs one record per request, in a single save, through `AgentActionLogger`.
   - Each record names the household and the conversation, which is the session ID.
   - Each failure gets its log record's number as the reference the customer can quote.
   - A request the service never answered fails rather than going unanswered.
   - The answers come back in request order.
7. The actions also share four small helpers:
   - `toId` turns the model's text into an ID, or null.
   - `evidenceLines` passes a dispute's evidence list on.
   - `entry` builds a log entry for the one action that doesn't use `Calls` (`RecordHandoffAction`).
   - `failIfSimulated` throws a test's simulated failure inside an action's service call.

**What can go wrong:** A bug in an action can't leave a request unanswered or unlogged: a request with no answer fails, and every request gets a log record. The logger never throws, so a logging problem can't break the answer a customer is waiting for.

**How it's tested:** `AgentActionsTest` covers the edges that no single action reaches:
- Only a verified household's request goes on. A service answer handed in for a declined request changes nothing.
- Only a blank or a well-formed ID goes on, and a declined request stays declined.
- An exception fails every request that was sent, including one already answered. A request declined before the call keeps its decline.
- A request the service never answered fails with a reference, and its log says "No answer from the service".
- A service's own failure message reaches the log.

Each action's own test proves the same paths end to end, with a simulated failure. `AgentAccessTest` runs them all as the agent user.
