# Steward — Agentforce for a Residential Solar Servicer

Steward is the second Lumenfield Home Energy project, built on the same Salesforce org as [Accord](https://github.com/zana-yocum/Lumenfield-accord). Accord made every promise, dispute and credit a governed record. Steward lets customers use those records themselves, through a portal and an AI service agent, and gives reps an AI assistant for everything else.

**The rule it's built around:** the agent can never do what a person in the same seat can't. It acts only for the logged-in customer's household, every record it creates goes through Accord's policy, and every action it takes, or declines, is logged for a supervisor.

**Status:** Phase 5 of 10 in progress: the rep assistant, three buttons in the Collections Console that write a pre-call briefing, a dispute summary and a follow-up email draft from the records, each with the clicking person's own access. Phase 4, the customer portal, is done and verified in the org. Next: the service agent. **Start here:** [Brief](docs/brief.md) · [Requirements](docs/requirements.md) · [Decisions](docs/decision-log.md) · [Explainers](docs/explainers/README.md)

---

## What it adds to Accord

| Area | Planned |
|---|---|
| Customer portal | Experience Cloud (LWR): balance, statements, payments, commitments from signing, disputes. Household access through a sharing set |
| Service agent | Agentforce, written in Agent Script: billing questions, payment arrangements within policy, payments, disputes with the right evidence list, handoff to a person over Enhanced Chat and Omni-Channel |
| Rep assistant | Prompt Builder: account briefing before a call, dispute summary, follow-up draft |
| Code | Apex services in user mode with at least 90% coverage and real assertions; a Lightning web component timeline with Jest tests |
| Integration | Stripe test mode through Named and External Credentials, scheduled reconciliation, a platform event; no public endpoint |
| Data 360 | Solar production through the Ingestion API, matched to households; a production-versus-guarantee insight that opens credit reviews |
| Release | GitHub Actions: Code Analyzer, Jest, validated deploys, quick deploy on merge. The agent ships through the same pipeline |

## How it's being built

The same way as Accord: requirements before configuration, decisions written down with the options that were rejected, every component traceable to a story, and pass or fail only from evidence in the org.

| # | Phase | Status |
|---|---|---|
| 1 | Requirements: 18 stories, 6 agent guardrails, 11 decisions | Done, 2026-10-16 |
| 2 | Pipeline: validate on every pull request, quick deploy on merge, CI sign-in by certificate | Done, 2026-10-17 |
| 3 | Apex services and the agent action log: 13 classes, 83 tests, a 90% per-class coverage gate | Done, 2026-10-18 |
| 4 | Customer portal: six pages on an LWR site, household sharing, 6 more classes, 105 Apex tests in all and 48 Jest tests with accessibility checks | Done, 2026-10-21 |
| 5 | Rep assistant: three prompt templates grounded in Apex with the user's own access, three console buttons, and `docs/agent-governance.md` | In progress |
| 6 | Service agent | Planned |
| 7 | Payments | Planned |
| 8 | Data 360 | Planned |
| 9 | Customer timeline component | Planned |
| 10 | Testing and release | Planned |

Phases 1–6 and 10 are the core release. Phases 7–9 follow.

## Repository

```
.github/workflows/        validate.yml (pull requests) and deploy.yml (merges to main)
force-app/main/default/   Steward metadata (source format)
  classes/                Apex services and their tests
  genAiPromptTemplates/   The rep assistant's three prompt templates
  lwc/                    The portal's pages and the rep assistant's buttons
  objects/                Agent_Action_Log__c
  customMetadata/         Steward's policy settings
manifest/                 Retrieve manifests, one per phase
scripts/                  check_coverage.py, the 90% per-class coverage gate
tests/
  agent/                  Agent test specs (Phase 10)
  pipeline/               Tests for the pipeline's own scripts
docs/
  brief.md                The problem, scope, architecture and phases
  requirements.md         Stories, guardrails, what each audience can see, traceability
  decision-log.md         S-01 to S-22
  agent-governance.md     What each AI feature reads, what reaches a model, and the Trust Layer settings
  pipeline.md             How a change reaches the org, and how the pipeline was set up
  conventions.md          Naming and coding standards
  explainers/             One page per Apex class, component and prompt template, written for an interview walkthrough
  screenshots/            The portal as each demo customer sees it (phase-4/)
  open-items.md           Everything deferred, flagged or not done yet
code-analyzer.yml         Changes to Code Analyzer's default rules, each with its reason
CHANGELOG.md
```

## The Apex, in one paragraph

Every service checks the household first, in user mode, so an ID from someone else's household gets the same answer as an ID that doesn't exist. Services return outcome codes and figures, never sentences, so the agent can only word what the records say. Every limit comes from Accord's policy records, and writes go through Accord's own flows and rules. If Accord would send a new promise for approval, the service rolls it back rather than leave a supervisor something to approve. Only three operations run outside user mode, and each is a named decision with its own tests: the commitments read (S-08), the action log write (S-09) and the dispute insert (S-14). The rep assistant's Apex reads in user mode too, so a briefing holds only what the rep can see, and names, contact details and record IDs never reach a model (S-20). The [explainers](docs/explainers/README.md) walk through each class.

Component descriptions cite stories (`ST-xx`) and decisions (`S-xx`), so anything in `force-app/` can be traced back to why it exists.

## Built with

Salesforce Developer Edition (Winter '27, API 68.0) · Agentforce and Agent Script · Prompt Builder · Experience Cloud · Data 360 · Apex · Lightning Web Components · Salesforce CLI · GitHub Actions · Stripe (test mode)

All data is invented. No real customer information appears in this repository or the org, and payments run in Stripe test mode only.
