# Steward — Brief

**Agentforce for Lumenfield: a customer service agent and a rep assistant that work inside the same guardrails as a person, on Accord's governed data, with code where declarative tools stop.**

Second project on the Lumenfield org, after Accord. Same org and data model, its own repo (`lumenfield-steward`).

---

## Why this project

Accord shows declarative depth: requirements, a security model, Flow, Service Cloud, data quality, and testing with evidence. Current Salesforce postings and the 2026 admin survey point to five things it doesn't show:

| Gap | What employers ask for | Where Steward covers it |
|---|---|---|
| Agentforce | Agents, actions, prompt templates, guardrails on agent access, moving agent configuration between orgs | A service agent written in Agent Script, a rep assistant in Prompt Builder, a least-privilege agent user, agent test suites |
| Data 360 | Data streams, data model, identity resolution, calculated insights, access | Solar production data matched to customer accounts; a production-guarantee insight the agent can use |
| Integration | Secure integrations that respect governor limits | Payments through Stripe test mode with Named and External Credentials, async reconciliation, a platform event |
| Code | Reading Apex at minimum; writing Apex and LWC as a plus | Apex services and tests, a Lightning web component with Jest tests |
| Modern release management | Git-based deployment instead of change sets | A GitHub Actions pipeline: static analysis, unit tests, validated deploys |

It also shows judgment about AI, the top concern in the survey: **an agent should never be able to do what a person in the same seat can't.**

---

## The problem

Accord made promises, disputes and credits governed records inside Lumenfield. Customers still have to call for everything: why the bill went up, what they were promised at signing, whether they can split a payment, how to dispute a charge. And every call starts with a rep reading account history to catch up.

Steward moves the routine questions to self-service and gives reps a head start on the rest, without giving an AI agent more reach than a rep has.

## Users

| Persona | Uses | Goal |
|---|---|---|
| Customer | Customer portal and chat agent | Answer billing questions, arrange or make a payment, open a dispute, without calling |
| Collections rep | Rep assistant in the Collections Console | A briefing before every call, a draft follow-up after |
| Dispute specialist | Rep assistant | A first-pass summary of a dispute with the commitments and evidence attached |
| Collections supervisor | Agent activity dashboard | See what the agent handled, handed off or declined |
| Admin | Pipeline and agent tests | Change the agent and the code safely, with tests that run on every change |

---

## Scope

### In
1. **Customer portal** on Experience Cloud (LWR): balance, statements, payments, open disputes, and "What we promised you" (commitments from signing). Customers see only their own household, through sharing sets.
2. **Service agent** in the portal through Enhanced Chat, built in the Agentforce Builder with Agent Script. Subagents: billing questions, what we promised, payment arrangements, making a payment, disputes, handing off to a person. Every action goes through Accord's policy: promise limits, dispute evidence checklists, credit limits.
3. **Rep assistant** in the console: account briefing, dispute summary and follow-up draft, built in Prompt Builder and grounded in Accord's records.
4. **Apex services** behind the agent's actions: account snapshot, statement explanation, payment arrangements within policy, dispute intake, commitments. Bulk-safe, in user mode, at least 90% coverage with real assertions.
5. **Payments** through Stripe test mode: Apex callouts through a Named Credential and External Credential, a scheduled job that reconciles completed payments, and a platform event that creates the Lease Payment so Accord's flows take over. No public inbound endpoint.
6. **Data 360:** monthly solar production loaded through the Ingestion API, matched to Accord's households, and a calculated insight comparing production with the guarantee. A shortfall opens a Production Guarantee credit review, and the agent can answer "did my system produce what you guaranteed?"
7. **Lightning web component:** a customer timeline (statements, payments, promises, disputes, credits, commitments) on the console account page and in the portal, with Jest tests.
8. **Pipeline:** GitHub Actions on every pull request runs Salesforce Code Analyzer, Jest, and a validated deploy with local Apex tests; quick deploy on merge. The Agent Script ships the same way.
9. **Agent governance:** a dedicated least-privilege agent user, Einstein Trust Layer settings recorded, agent test suites that include attempts to reach another customer's data.

### Out
- Voice, Slack, and mobile app changes
- Real payment processing, CPQ and Revenue Cloud
- Rebuilding anything Accord already does. Steward relies on Accord's flows and rules instead of copying them.

---

## Architecture

```
Customer ── Portal (Experience Cloud, LWR) ── Enhanced Chat ── Service agent (Agent Script)
                 │                                                │
                 │ sharing sets                       subagents → actions
                 ▼                                                ▼
        Accord data model ◄──── Apex services (user mode) ◄──── identity from the login (S-07)
        Account · Statement ·         │                  └──── Agent Action Log (S-09)
        Payment · Promise ·           ├── StripeClient ── Named + External Credential ── Stripe (test)
        Adjustment · Commitment       │        ▲
                 ▲                    │   Reconcile job ── Payment_Received__e ── Lease Payment
                 │                    │
        Data 360: production stream ── identity resolution ── production vs guarantee insight
                 │
Rep ── Console ── Rep assistant (Prompt Builder) · Customer timeline (LWC)

GitHub ── Actions: Code Analyzer · Jest · validate + local tests ── quick deploy on merge
```

---

## Requirements and decisions

- **[Requirements](requirements.md):** 18 stories (11 Must, 6 Should, 1 Could), six agent guardrails, ten non-functional requirements, and what each audience can see.
- **[Decision log](decision-log.md):** S-01 to S-11. Decided: Apex for actions with Accord keeping the policy (S-03), validating against the org instead of scratch orgs (S-05), what the agent may never do (S-06), identity from the login and never from the model (S-07), the Agent Script in Git (S-10). The rest are starting positions confirmed in the phase that builds them.
- **[Conventions](conventions.md):** naming and coding standards.

---

## Phases

Paced against Accord, which took about four weeks for ten phases.

| # | Phase | Delivers |
|---|---|---|
| 1 | Requirements | Stories with Given/When/Then and adversarial cases, decisions, conventions, repo |
| 2 | Setup | Pipeline skeleton, External Client App for the pipeline, push and branch protection |
| 3 | Apex services | Snapshot, statement explanation, arrangement, dispute intake and commitment services, the action log, tests |
| 4 | Customer portal | LWR site, customer users, sharing set, pages for balance, statements, commitments, disputes |
| 5 | Rep assistant | Briefing, dispute summary and follow-up templates in the console; governance document |
| 6 | Service agent | Agent Script, agent user, actions, Enhanced Chat in the portal, handoff routing, Trust Layer settings |
| 7 | Payments | Stripe test mode, credentials, callouts, reconciliation, platform event, logging |
| 8 | Data 360 | Ingestion API stream, data mapping, identity resolution, calculated insight, credit review |
| 9 | Customer timeline | Lightning web component, Apex controller, Jest tests, placed in console and portal |
| 10 | Testing and release | Agent test suites, UAT scripts, release notes, case study, walkthrough video |

**The core release** is phases 1–6 and 10: Agentforce, Apex, the portal, the pipeline and agent testing cover the biggest gaps. Phases 7–9 ship after, and the case study grows as they land.

---

## Org check

**2026-10-15 and 2026-10-16**
- Licensed and ready: Agentforce, Agentforce Service Agent, Einstein Prompt Templates and Data Cloud permission set licenses; Einstein Agent user licenses (201); five Customer Community and five Customer Community Plus licenses.
- Already on: Omni-Channel (Messaging and Phone service channels exist). Messaging is available with no channels yet.
- Agentforce: the admin has the Einstein Agent Platform permission and the new Agentforce Builder is available. No agents exist yet.
- Off for now: Digital Experiences (turned on in Phase 4) and Dev Hub (stays off, S-05). The Trust Layer's master Prompt Security setting reads off (decided in Phase 6).
- Couldn't be read through the API: the "Turn on Einstein" switch. Checked by hand in Phase 2.

## Constraints

- Developer Edition limits: five customer licenses, capped Einstein and Data 360 usage, four full Salesforce licenses (three in use) for persona testing.
- Customer licenses can't be given opportunity access, and each customer user can reach at most 10 custom objects (S-04, S-08).
- Stripe test mode needs a free Stripe account. No real cards or money.
- Every Apex class, component, prompt template and subagent ships with a plain-English explainer, so each one can be walked through in an interview.

## Certifications that pair with it

Salesforce Certified Agentforce Specialist, after Phase 6. Platform Developer I, if developer roles become the target.
