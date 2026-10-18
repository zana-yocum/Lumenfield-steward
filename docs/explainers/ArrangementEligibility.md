# ArrangementEligibility

**What it does:** Runs the self-service rules for a promise to pay, in a fixed order, and returns the first rule a request breaks along with the figures the customer is told.

**Why it exists:** ST-04, ST-12, GR-03. Keeping the rules apart from the saving and rollback in `PaymentArrangementService` makes each rule easy to read, test and walk through. The order matters: a request that should go to a person must never be told about amounts first.

**How it works:**
1. For a whole batch, it reads the visible households (status, broken promises in 90 days, past-due balance) and their open promises in user mode, once. It also reads three policy values through `PolicySettings`: the promise window, the broken-promise limit and the coverage percentage.
2. `check` runs the rules in this order:
   - **Complete request?** An account, a date and an amount above zero, or `INVALID_REQUEST`.
   - **In reach?** Otherwise `NOT_FOUND`.
   - **Hand-offs:** an account status other than Current or Delinquent (`ACCOUNT_STATUS`), then broken promises at or over the limit (`BROKEN_PROMISE_LIMIT`). Hand-offs carry no figures, so no collections field is revealed.
   - **Declines:** nothing past due (`NOTHING_PAST_DUE`), an Active or Pending Approval promise already (`EXISTING_PROMISE`), a date before today (`DATE_IN_PAST`), a date past the window (`DATE_OUTSIDE_WINDOW`), or less than the minimum (`AMOUNT_BELOW_MINIMUM`).
   - Otherwise `ELIGIBLE`.
3. The statuses that allow self-service are listed explicitly (Current and Delinquent). A status Accord adds later hands off until someone decides otherwise.
4. The minimum is the past-due balance times the coverage setting, rounded up to the cent, and never below the full past-due balance. That floor isn't a tunable value: Accord's `Out_of_Policy__c` formula sends any promise below the past-due balance for approval, so self-service can't accept less.

**What can go wrong:** A missing policy record throws `PolicySettingException` before any check runs, so a request is never judged against a guessed rule.

**How it's tested:** Through `PaymentArrangementServiceTest`, which covers every rule and its order. `theMinimumIsNeverBelowTheFullPastDueBalance` tests the minimum directly: a setting of 80% still asks for the full $190.00, 110% asks for $209.00, no setting means the full balance, and $33.333 rounds up to $33.34.
