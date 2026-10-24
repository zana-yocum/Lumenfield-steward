# PromptRunner

**What it does:** Runs a Steward prompt template for one record and returns the model's text. It's the only place Steward's Apex calls a model.

**Why it exists:** ST-08 to ST-10, S-21. One place for the call means one place to see what's sent, and one place for a test to put a stand-in.

**How it works:**
1. `generate(template, input, recordId)` sends the record's ID as the template's input (`Input:Household` or `Input:Dispute`) to `ConnectApi.EinsteinLLM.generateMessagesForPromptTemplate`, as the running user, with the application name Salesforce documents for calls from Apex.
2. Prompt Builder runs the template's Apex as the same user, merges its data, and sends the prompt through the Einstein Trust Layer.
3. `firstText` returns the first generation's text, and throws `PromptRunnerException` if there isn't any.
4. Tests set `PromptRunner.model` to a stand-in, because a test can't reach a model.

**What can go wrong:** Any failure (no text, a missing template, a refusal, the service unavailable) comes back as an exception. `RepAssistantController` turns it into a failed result, and the rep is asked to try again.

**How it's tested:** `PromptRunnerTest` (3 tests): a generation goes to whichever model is in place; only a generation with text is accepted; and the real call is built and, since a test can't reach a model, fails as an exception. Real generations are checked in the org (`docs/agent-governance.md`).
