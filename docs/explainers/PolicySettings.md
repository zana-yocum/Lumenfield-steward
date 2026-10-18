# PolicySettings

**What it does:** Reads policy numbers, like the 30-day promise window, from Accord's `Policy_Setting__mdt` records. It's the only class that reads them.

**Why it exists:** ST-04, S-03. No limit, day count or percentage is written into Steward's code. Accord's flows and formulas read the same records, so when a supervisor changes the promise window, Accord and the agent change together. A rule copied into code would drift.

**How it works:**
1. `getNumber(name)` returns the record's `Number_Value__c`.
2. `getWholeNumber(name)` does the same for values that must be whole numbers, such as day counts and limits, and refuses fractions.
3. The setting names Steward uses are constants on the class (`PROMISE_WINDOW_DAYS`, `SELF_SERVICE_BROKEN_PROMISE_LIMIT`, `SELF_SERVICE_MIN_COVERAGE_PCT`), so a typo is a compile error, not a silent miss.
4. `testOverrides` is a test-only hook. It lets a test make Steward's reading of a policy disagree with Accord's, to prove the service still never leaves a promise that needs approval (see `PaymentArrangementService`). Only test code can set it.

**What can go wrong:** A missing record, a blank name or a blank value throws `PolicySettingException` naming the setting. The caller stops instead of guessing a default. A wrong guess on a collections policy is worse than a clear failure.

**How it's tested:** `PolicySettingsTest`. Values match Accord's records exactly. Both of Steward's new settings exist in the org. A missing setting and a blank name throw, and the message names the setting. A fractional value is refused as a whole number. A test override replaces the record's value.
