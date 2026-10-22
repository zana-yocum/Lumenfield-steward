# AgentActionLogger and Agent_Action_Log__c

**What it does:** Writes one `Agent_Action_Log__c` record for every action the agent takes: the household it served, which action ran, the outcome (Completed, Declined by Policy, Handed Off or Failed), the reason code, a short line of details and the conversation it happened in.

**Why it exists:** ST-11, S-09, GR-06. Supervisors need to see what the agent did, and above all what it refused. A declined request changes nothing else in the org, so without this record there would be no trace that a customer asked for 60 days and was told no. Only the action knows the reason, so the action writes the record.

**How it works:**
1. An action builds an `Entry` from the service's result: `new AgentActionLogger.Entry(accountId, 'CreatePaymentArrangementAction', result)`. The outcome and reason are copied from the result, so they can't be mistyped. Details and the conversation ID are optional.
2. Each entry becomes a log record. The outcome code is turned into its label through `StewardOutcome.logLabel`. Card numbers are removed from the details (`SensitiveText`), and every text value is cut to its field's length, read from the field itself.
3. All records are saved in one insert, with `allOrNone` off: one bad entry is reported in its result and the rest still save.
4. `logForReference(entry)` saves one entry and returns its auto-number, such as AAL-000123, or null if it couldn't be saved. The portal gives that number to a customer as the reference to quote when something fails (NFR-07, `PortalFailure`). The number is read back in the same `Elevated` class, because nobody who meets a failure can read the log.
5. The insert runs in an inner `Elevated` class, without sharing and in system mode (S-09). That's deliberate: a request about an account the caller can't see must still be logged, and the agent user needs no access to the log object at all. Reading the log is the opposite. The object is Private, so only supervisors and admins will see it (permission sets in Phase 6).

**The object:** `Agent_Action_Log__c`, auto-numbered `AAL-000001`, Private, reportable, not searchable. Fields: `Account__c` (lookup, cleared if the account is deleted), `Action__c`, `Outcome__c` (required, restricted picklist), `Reason_Code__c`, `Details__c` (2,000 characters) and `Conversation_Id__c`.

**What can go wrong:**
- An outcome code that isn't one of the four is saved as Failed, with "Unknown outcome code: X" in the details, so the caller's bug is visible instead of the entry being lost.
- An entry with no result at all is saved as Failed.
- A save that fails, such as a contact ID in the account field, comes back as a failed result. The logger never throws, so a logging problem can't break the action the customer is waiting on.

**How it's tested:** `AgentActionLoggerTest`. All four outcomes are saved with the right label, reason and conversation ID. A card number in the details is removed, and text longer than a field is cut to fit. An unknown code and a missing result are kept as failures. A user who can't see the account still leaves a record. A bad entry is reported, not thrown. A saved entry's reference is its record's number, and an entry that can't be saved has none. 200 entries save in a single DML statement. The tests read records back with `WITH SYSTEM_MODE`, because they check what was stored. Until Phase 6 no profile or permission set can read the log's fields, which is also why the first validation's plain queries failed.
