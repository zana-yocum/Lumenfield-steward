# PortalFailure

**What it does:** Handles a failure in a portal controller: the details go into the action log, and the customer gets back only the log record's number, such as AAL-000123, to quote if they get in touch.

**Why it exists:** NFR-07, S-09. Customers never see an error's details: they mean nothing to a customer and can reveal how the system is built. But "something went wrong" alone leaves support with nothing to go on. A reference connects the two: the customer quotes it, and a supervisor finds the full error in `Agent_Action_Log__c`.

**How it works:**
1. The controller creates one where the failure happened: `new PortalFailure(householdId, 'PortalAccountController.getMyAccount')`.
2. `recordException(result, error)` is for an exception nobody planned for. The result becomes `FAILED` with reason `UNEXPECTED_ERROR`, and the log's details get the exception's type and message.
3. `record(result, detail)` is for a failure a service reported, such as a save the platform refused. The detail goes to the log only, and the controller then clears it from what the customer receives.
4. Both write through `AgentActionLogger.logForReference`, which saves the log record and reads back its auto-number. The number lands on the result's `reference` field, and the page shows it in a sentence.

**What can go wrong:** If the log record itself can't be saved, there's no reference to give. The result still says `FAILED`, and the page falls back to "Something went wrong on our side. Please try again later." The logger never throws, so a logging problem can't hide the original failure.

**How it's tested:** `PortalControllersTest`. `failuresComeBackAsAReferenceToQuote` makes every controller method fail with a simulated exception and checks seven distinct references, each matching a log record that names its method and the error. `aCustomerWhoCannotSetTheReasonIsRefusedByName` checks a reported failure: the customer gets a reference and no detail, and the log names the field.
