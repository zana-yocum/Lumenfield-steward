# repAssistantShared

**What it does:** The code the rep assistant's buttons share: their text, the outcome codes the server returns, and what to show for a result. It has no screen of its own.

**Why it exists:** ST-08 to ST-10, S-21. Three buttons show the same kinds of things, and should say them the same way.

**How it works:**
1. `LABELS` imports the eleven `Steward_Rep_*` labels the components show, so wording changes need no code changes.
2. `viewOf(result)` returns the text for a `COMPLETED` result. Otherwise it returns a message for the reason (`NOT_FOUND`: "This record isn't available to you."; `NO_ATTEMPT_TODAY`: "Log today's contact attempt first…"), or the general "couldn't write this just now" message, with the server's detail.
3. `viewOfError(error)` does the same for an Apex call that threw, with the error's message as the detail.

**What can go wrong:** A reason code it doesn't know gets the general message.

**How it's tested:** Through the three buttons' Jest tests, which check each message a rep can see.
