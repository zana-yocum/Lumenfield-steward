# Changelog — Steward

Newest first. One entry per phase.

## v0.2 — 2026-10-16 — Phase 2: Pipeline (in progress)

Every org change now goes through a pull request that's validated against the org before it can merge. Phase 2 closes when the first deploy is confirmed in the org.

### Added
- `.github/workflows/validate.yml`: on every pull request, a Prettier check, Jest (once components exist), Code Analyzer with critical and high findings blocking, sign-in as the Steward CI user by JWT, and a check-only deployment with local Apex tests. The validation's job ID is kept for 10 days
- `.github/workflows/deploy.yml`: on a merge that changes `force-app/`, finds the pull request's passing validation and quick-deploys it, falling back to a fresh deploy with the same tests if Salesforce won't accept the quick deploy. Refuses changes that didn't come through a validated pull request
- `docs/pipeline.md`: how a change reaches the org, what protects each step, the secrets, known limits, key rotation, and the setup steps
- The first change sent through the pipeline: three new `Policy_Setting__mdt` records, `Self_Service_Broken_Promise_Limit` (2), `Self_Service_Min_Coverage_Pct` (100) and `Production_Guarantee_Pct` (90). Moved up from Phase 3 because they're small, real and harmless until Phase 3 code reads them
- `package-lock.json`, so the pipeline installs exactly the same tool versions every time
- Decisions S-12 (the pipeline signs in as its own user, with a certificate) and S-13 (pull requests for anything that deploys; docs can go straight to `main`)

### Changed
- ST-13 criteria: the quick-deploy fallback and the refusal of direct pushes are now acceptance criteria
- Prettier checks code files only. Metadata XML stays exactly as Salesforce retrieves it, so retrieves don't create formatting noise
- `@prettier/plugin-xml` removed; nothing uses it now

### Checked before delivery
- Both workflows pass actionlint, including its shell checks
- Code Analyzer 5.16 on `force-app/`: 0 violations
- The three records convert to Metadata API format cleanly (one `CustomMetadata` type, API 68.0)

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
