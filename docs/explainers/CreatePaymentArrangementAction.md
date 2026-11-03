# CreatePaymentArrangementAction

**What it does:** Saves the arrangement the customer confirmed: an Active promise to pay. It's saved through Accord's flow, which pauses collections until the promise date plus the grace days.

**Why it exists:** ST-04, GR-02, GR-03, GR-05. A customer can set up what a rep could, inside policy, at any hour. The agent reaches this action only after two things: Check Payment Arrangement said eligible, and the customer said yes to the exact amount and date. That order is in the agent's script (GR-05).

**How it works:**
1. It takes the same inputs as the check. `AgentActions.Calls` finds the household, or declines the request.
2. `PaymentArrangementService.createArrangements` does three things:
   - It checks the policy again, because things can change between the check and the yes.
   - It saves the promise in user mode, as the agent user.
   - It rolls the save back if Accord's flow would send the promise for approval (`WOULD_NEED_APPROVAL`). The agent never leaves anything for a supervisor to approve (GR-03).
3. The whole call sits inside a savepoint. An exception rolls every save back, so nothing half-saved is left behind an error the customer is told about. Every request in the call then fails, with a reference.
4. The output has the promise's number, status, date, amount and hold-until date. If the promise was refused, it has the rule's figures instead.
5. The log line has what was asked: "Create arrangement: 120.00 on 2026-11-10". On `SAVE_FAILED`, it has the platform's message instead.

**What can go wrong:**
- Every rule from the check can still refuse.
- `WOULD_NEED_APPROVAL` when Accord's flow disagrees.
- `SAVE_FAILED` when a save is rejected.
- `FAILED` with a reference on an exception.

The agent user needs edit access to the household's account to add a promise to it, because a promise is a master-detail child of the account. The sharing rule gives that access, and the permission set keeps every account field read only (S-01).

**How it's tested:** `CreatePaymentArrangementActionTest`:
- A confirmed arrangement saves as an Active promise.
- Less than the minimum saves nothing.
- A chat with no customer behind it creates nothing.
- A failure saves nothing and gives a reference.

`AgentAccessTest` saves one as the agent user.
