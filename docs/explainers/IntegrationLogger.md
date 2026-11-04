# IntegrationLogger

**What it does:** Records every call Steward makes to an outside system on `Integration_Log__c`: the provider, the operation, the outcome, the HTTP status, how long it took, the household and statement it was for, and the provider's own ID. Support staff use it to answer "did the payment reach Stripe, and what did Stripe say?" without reading code or debug logs.

**Why it exists:** ST-05, S-28, NFR-07. An integration that fails quietly is the hardest kind of problem to support. A customer quotes their reference. The action log says what they were doing and names the integration log record, and that record has Stripe's own answer.

**How it works:**
1. `StripeClient` builds an `IntegrationLogger.Call` for each request, records it, and fills in the outcome, status and duration as the answer comes back.
2. **Calls are kept in memory, not saved.** Salesforce refuses a callout after a save in the same transaction, so saving each call as it happened would block the next one.
3. The caller runs `save()` after its last callout. It saves every call kept in one statement, in system mode, and returns their numbers (`INT-000012`) for the action log to name.
4. Text is cut to fit each field, and card numbers are removed before saving (`SensitiveText`).

**What can go wrong:**
- A row refused for its links, such as a payment for a statement that no longer exists, is saved again without them, with the IDs at the start of its details. That's the log support needs most.
- Any other refusal is left out, never thrown, so a log that can't be saved never breaks the payment it describes.
- With nothing to save, `save()` makes no save at all.

**How it's tested:** `IntegrationLoggerTest`:
- two calls are saved together, with numbers, and nothing is left waiting
- long text is cut to 2,000 characters, and a card number never reaches the record
- nothing to save makes no save
- a call about a statement that doesn't exist is still saved, without the link, with the statement's ID in its details
- a customer, who can't read the log, still gets their call recorded
