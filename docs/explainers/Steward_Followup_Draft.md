# Steward_Followup_Draft

**What it does:** The prompt template behind the Follow-up Draft button. It writes the body of a short servicing email after today's contact attempt: two or three paragraphs, under 120 words, with no greeting, sign-off or names, which `RepAssistantController` adds.

**Why it exists:** ST-10, S-20. The customer gets what was agreed in writing the same day, written from the record of the call.

**How it works:**
1. A flex template with one input, `Household`, and one Apex merge field: `{!$Apex:FollowupDraftPrompt.Prompt}`.
2. The outcome decides the email. Promise Made confirms the promise exactly as recorded, or says it's being reviewed when it's Pending Approval. A conversation states the past-due balance and invites questions; Disputed Balance adds how to open a dispute. No Answer, Left Voicemail and Wrong Number say we tried to reach them. Requested No Further Contact confirms the request was recorded, and Hardship or Bankruptcy Mentioned says someone will follow up; neither asks for payment or mentions an amount. A draft is written for every outcome (S-21).
3. Five rules: servicing only, with no offers, promotions or marketing of any kind, whether or not Do Not Contact is set (Accord D-05); figures copied exactly; no threats or pressure (credit reporting, agencies, legal action, fees); no promises beyond the data; warm, plain and brief.

**What can go wrong:** A draft can still read wrongly, which is why it opens in the composer for the rep to edit and nothing is sent automatically.

**How it's tested:** Its data is proven by `FollowupDraftPromptTest`, and the email around it by `RepAssistantControllerTest`. In the org after the deploy: drafts for a promise and for a missed call, checked for the promise's amount and date and for no promotional content (`docs/agent-governance.md`).
