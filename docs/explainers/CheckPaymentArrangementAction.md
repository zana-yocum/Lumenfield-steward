# CheckPaymentArrangementAction

**What it does:** Tells the logged-in customer whether an arrangement they describe, an amount by a date, is one they can set up themselves. It saves nothing. There are three possible answers:
- eligible
- declined by a named rule, with the figure that rule allows (the minimum amount, or the latest date)
- handed to a person

**Why it exists:** ST-04, GR-03, GR-05, S-03. The agent checks before it asks the customer to confirm, so a customer is never asked to agree to something the policy will refuse. The rules are Accord's. They're read from the same policy records Accord's own flow reads (`PolicySettings`), so the check and the save can't disagree.

**How it works:**
1. The inputs are `sessionId`, `promiseDate` and `amount`. `AgentActions.Calls` finds the household, or declines the request.
2. `PaymentArrangementService.checkEligibility` runs `ArrangementEligibility`'s rules in order, once for the whole call.
3. The answer is one of three kinds:
   - **Eligible:** `COMPLETED` with `ELIGIBLE`.
   - **Handed off:** `HANDOFF` with `ACCOUNT_STATUS` (Default Review, Hardship Review or Closed) or `BROKEN_PROMISE_LIMIT`. A person handles these, so they come first and carry no figures.
   - **Declined:** `DECLINED_POLICY` with the rule and its figures. The rules are `DATE_IN_PAST`, `DATE_OUTSIDE_WINDOW` (with the latest allowed date), `AMOUNT_BELOW_MINIMUM` (with the minimum), `EXISTING_PROMISE` (with the promise already in place) and `NOTHING_PAST_DUE`.
4. The log line has what was asked: "Check arrangement: 120.00 on 2026-11-10".

**What can go wrong:** The same declines as every action. An exception gives `FAILED` and a reference. Nothing is ever saved.

**How it's tested:** `CheckPaymentArrangementActionTest`:
- An arrangement inside policy is eligible, nothing is saved, and the log has what was asked.
- A date outside the window says how far out is allowed, using the window from Accord's policy record.
- An anonymous chat gets no figures.
- A failure gives a reference.

`AgentAccessTest` runs it as the agent user.
