# Explainers

One page per Apex class, Lightning web component, prompt template and agent subagent (NFR-04). Written so the component can be walked through in an interview without opening the code. Name each file after the component: `PaymentArrangementService.md`.

## Template

```markdown
# <ComponentName>

**What it does:** One or two sentences, in plain English.

**Why it exists:** The stories and decisions it serves (ST-xx, S-xx).

**How it works:**
1. Step one
2. Step two

**What can go wrong:** The failure cases it handles, and what the customer or rep sees in each one.

**How it's tested:** The test class or suite, and what it proves. Include the scoping test if the component touches household data.
```
