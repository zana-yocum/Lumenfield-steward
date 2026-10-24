# repBriefing

**What it does:** The Briefing button on a household in the Collections Console. It writes the briefing as soon as the panel opens, shows it, and writes it again on request.

**Why it exists:** ST-08, S-21. A rep gets the account's story in one click before dialling.

**How it works:**
1. It's a screen quick action (`Account.Steward_Briefing`). When the quick action gives it the household's ID, it calls `RepAssistantController.briefing` once.
2. `repGeneratedText` shows the spinner, then the briefing or the reason there isn't one.
3. **Write again** asks again; **Close** closes the panel.

**What can go wrong:** A household the rep can't see, a failed generation and a server error each show one plain message, with the detail for a failure.

**How it's tested:** `repBriefing.test.js` (6 tests): the briefing for the household on the page (with `toBeAccessible`); the not-found message; a failed generation with its detail; a server error; Write again and Close; and nothing asked until the household is known.
