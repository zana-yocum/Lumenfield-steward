# Steward Agent dashboard

**What it does:** Shows a collections supervisor what the service agent did in the last 30 days: every request by outcome (completed, declined by policy, handed off, failed), by day and by action, and which reasons sent customers to a person or stopped them. The **Agent Failures** report lists each failed request with the log number a customer would quote.

**Why it exists:** ST-11, ST-07, NFR-07. A supervisor can only trust the agent with customers if they can see what it does, and catch it early when it's wrong. Every request the agent handles is already one `Agent_Action_Log__c` record (S-09); this puts them where a supervisor looks.

**How it works:**
1. Five reports in the **Steward Agent** folder, all on the action log's own report type, all for the last 30 days by when the request was logged:
   - **Agent Requests by Outcome**, grouped by outcome
   - **Agent Requests by Day**, grouped by day, then outcome
   - **Agent Requests by Action**, grouped by action, then outcome
   - **Agent Handoffs and Declines**, only those two outcomes, grouped by reason code
   - **Agent Failures**, a list, newest first, with the log number, action, reason code, household, conversation ID and details
2. The **Steward Agent** dashboard, in the **Steward Agent Dashboards** folder, draws the first four: a donut by outcome, a stacked column by day, and stacked bars by action and by reason.
3. **It runs as whoever is viewing it** (a dynamic dashboard), not as a fixed user. So it shows exactly what the viewer can read, and naming a user in the repository isn't needed.
4. Both folders are shared, view only, with the Collections Supervisor role.
5. `PS_Steward_Supervisor` gives supervisors read and **View All** on the action log. The log is Private, and its records are owned by the agent user or by customers, so read alone would have shown a supervisor nothing.

**What can go wrong:**
- A rep or specialist who opens the dashboard sees no figures: they have no access to the log (ST-11).
- Developer Edition allows only a few dashboards that run as the viewer. This is Steward's only one.
- Until the agent is live, the log holds only what the portal and the tests wrote, so the charts are nearly empty.

**How it's tested:** The pipeline's check-only deployment proves the reports and the dashboard are valid against the org's action log. What a supervisor sees is UAT-S11, once the agent has handled some conversations. That supervisors can read every log record is checked in the org after the deploy.
