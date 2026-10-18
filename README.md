# Steward — Agentforce for a Residential Solar Servicer

Steward is the second Lumenfield Home Energy project, built on the same Salesforce org as [Accord](https://github.com/Zana-yocum/lumenfield-accord). Accord made every promise, dispute and credit a governed record. Steward lets customers use those records themselves, through a portal and an AI service agent, and gives reps an AI assistant for everything else.

**The rule it's built around:** the agent can never do what a person in the same seat can't. It acts only for the logged-in customer's household, every record it creates goes through Accord's policy, and every action it takes, or declines, is logged for a supervisor.

**Status:** Phase 2 of 10 complete (pipeline). Next: Apex services. **Start here:** [Brief](docs/brief.md) · [Requirements](docs/requirements.md) · [Decisions](docs/decision-log.md)

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
| 3 | Apex services and the agent action log | Next |
| 4 | Customer portal | Planned |
| 5 | Rep assistant | Planned |
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
manifest/                 Retrieve manifests, one per phase
tests/agent/              Agent test specs (Phase 10)
docs/
  brief.md                The problem, scope, architecture and phases
  requirements.md         Stories, guardrails, what each audience can see, traceability
  decision-log.md         S-01 to S-13
  pipeline.md             How a change reaches the org, and how the pipeline was set up
  conventions.md          Naming and coding standards
  explainers/             One page per component, from Phase 3
  open-items.md           Everything deferred, flagged or not done yet
CHANGELOG.md
```

Component descriptions cite stories (`ST-xx`) and decisions (`S-xx`), so anything in `force-app/` can be traced back to why it exists.

## Built with

Salesforce Developer Edition (Winter '27, API 68.0) · Agentforce and Agent Script · Prompt Builder · Experience Cloud · Data 360 · Apex · Lightning Web Components · Salesforce CLI · GitHub Actions · Stripe (test mode)

All data is invented. No real customer information appears in this repository or the org, and payments run in Stripe test mode only.
