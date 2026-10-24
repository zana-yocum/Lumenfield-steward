# RepAssistantController

**What it does:** The server side of the rep assistant's three buttons. It checks each request, runs the template, and returns the text, or for a follow-up, an email for the composer.

**Why it exists:** ST-08 to ST-10, S-21. The checks belong before any model runs, and the email's recipient and greeting belong outside the prompt.

**How it works:**
1. `briefing(accountId)` checks the household with `HouseholdScope.isVisible`, then runs the briefing template. A household the person can't see gets `NOT_FOUND`.
2. `disputeSummary(caseId)` checks with `DisputeSummaryPrompt.isVisibleDispute`, then runs the summary template. Anything but a billing dispute the person can see gets `NOT_FOUND`.
3. `followupDraft(accountId)` checks the household, then asks `FollowupDraftPrompt.latestAttemptToday`. With no attempt logged today it returns `NO_ATTEMPT_TODAY`, and the rep is asked to log one first. Otherwise the template writes the body, and then the controller reads the primary contact's first name and email address in user mode, picks the subject from the outcome (a promise, nobody reached, or anything else), and builds the email: "Hi Sandra," ("Hello," without a first name), the model's paragraphs, and "Thank you," with the rep's name and the company's.
4. Every part of the email is escaped, so the model's text arrives in the composer as text, never as markup.
5. A model failure comes back as `FAILED` with `GENERATION_FAILED`, and the platform's message as `detail` for the rep to see under "try again".

**What can go wrong:** A rep who can't read the contact's email gets an empty To line and picks the recipient in the composer. Every check fails closed: nothing is sent to the model.

**How it's tested:** `RepAssistantControllerTest` (7 tests), with a stand-in model that records each call. Each button runs its own template for the record on the page. Nothing runs for a household the user can't see, a default review, or a follow-up with no attempt today. A model failure comes back as a failure. The follow-up's address, subject, greeting, escaped paragraphs and sign-off are exact. Each kind of outcome gets its subject.
