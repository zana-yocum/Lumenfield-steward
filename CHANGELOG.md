# Changelog — Steward

Newest first. One entry per phase.

## v0.1 — 2026-10-16 — Phase 1: Requirements

Stories, guardrails and decisions, written against what's actually in the org (read 2026-10-16) rather than against assumptions.

### Added
- `docs/requirements.md`: 18 stories (11 Must, 6 Should, 1 Could), each with Given / When / Then criteria and a negative case. Every agent story also has an adversarial case. Six agent guardrails (GR-01 to GR-06), ten non-functional requirements, a table of what customers, the agent and reps can each see, the Accord policy values and dispute evidence the stories depend on, and a traceability table
- `docs/decision-log.md`: S-01 to S-11. Five decided; six proposed, each with the phase that confirms it
- `docs/conventions.md`: naming and coding standards for Apex, Lightning web components, the agent, prompt templates, integrations, Data 360 and Git
- `docs/brief.md` and `docs/open-items.md`
- Project scaffold: `sfdx-project.json` (API 68.0), `.forceignore`, `.gitignore`, `package.json` and Prettier settings for later phases, pull request template, explainer template

### Findings that shaped the requirements
- **Commitments can't reach customers directly.** They're detail records of the opportunity, and customer licenses can't be given opportunity access. They'll go through a scoped read service instead (S-08), filtered on `Commitment__c.Account__c`, the lookup added by Accord's DEF-07.
- **Accord's policy already covers most of what the agent needs:** the 30-day promise window, 3 grace days, credit limits and 16 evidence requirements across 8 dispute reasons. Steward reads them rather than copying them (S-03). Three new policy values are proposed for self-service rules and the production guarantee.
- **Ready in the org:** Omni-Channel is on, Messaging is available, and the new Agentforce Builder with Agent Script is available. No agents exist yet.
- **Off for now:** Digital Experiences (Phase 4), Dev Hub (stays off, S-05), and the Trust Layer's master Prompt Security setting (decided in Phase 6).
