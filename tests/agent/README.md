# Agent tests

Test specs for the agent test suites, one per story with an agent-facing criterion, named `ST<nn>_<Topic>` (for example `ST12_Cross_Household`). Run before any agent version is activated (ST-12, ST-13).

| Suite | Story | Cases | Runs as |
|---|---|---|---|
| `ST01_Balance` | ST-01 | 4 | Sandra Barnett |
| `ST02_What_We_Promised` | ST-02 | 4 | Tanya Lattimore |
| `ST03_Bill_Changes` | ST-03 | 5 | a customer whose statements show each case |
| `ST04_Payment_Arrangements` | ST-04, GR-03, GR-05 | 5 | Tanya Lattimore |
| `ST05_Payments` | ST-05, GR-05 | 4 | Sandra Barnett |
| `ST06_Disputes` | ST-06, GR-05 | 6 | Tanya Lattimore |
| `ST07_Handoff` | ST-07, ST-11 | 4 | Sandra Barnett |
| `ST12_Cross_Household` | ST-12, GR-01 | 28 | Sandra Barnett |
| `ST16_Disclosure` | ST-16 | 6 | any customer |
| `ST18_Spanish` | ST-18 | 5 | Tanya Lattimore |

71 cases. `ST12_Cross_Household` is the activation gate: at least 25 attempts, and one failure blocks activation (ST-12).

## Status: drafts, until the agent exists

Each file follows the Salesforce CLI's agent test spec: a `name`, the agent as `subjectName`, and test cases with an `utterance` and an `expectedOutcome`, plus the subagent (`expectedTopic`) and actions (`expectedActions`) where they're certain. A case leaves those out where the right answer could go either way, such as a refusal that might or might not read the customer's own summary first, and is judged on its outcome alone.

Once the agent is created and retrieved:
1. Check each subagent and action name against the retrieved bundle, and the file format against `sf agent generate test-spec`.
2. Turn each spec into a test definition with `sf agent test create --spec tests/agent/<suite>.yaml`, and run it with `sf agent test run`.
3. Settle how a suite gets a logged-in customer. Every action declines a chat with no verified customer (S-23), so a suite run without one would pass `ST12_Cross_Household` for the wrong reason. The open question is in `docs/agent-design.md`.
4. Record each run's result in `CHANGELOG.md` and the open items, with the date.

## Why these cases

They're the acceptance criteria and adversarial cases from `docs/requirements.md`, written as a customer would type them. `ST12_Cross_Household` covers every way of naming someone else's household that ST-12 lists (name, address, account number, statement number, record ID), claims of authority, and the three injection phrases. Households and numbers in it are the demo data's, and every record in the org is invented (NFR-10).
