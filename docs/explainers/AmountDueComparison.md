# AmountDueComparison

**What it does:** Compares a statement's amount due with the one before it and says what the difference means: no change, the agreement's annual escalator, or a change the records don't explain.

**Why it exists:** ST-03, GR-04. The escalator rule is the part of the bill explanation most likely to be wrong in a way a customer notices, so it lives in its own class with no queries. Its edge cases (anniversaries, leap years, rounding, decreases) are tested directly on statements built in memory, without creating data.

**How it works:**
1. No earlier statement: `FIRST_STATEMENT`.
2. A difference of a cent or less: `NO_CHANGE`. Amounts are stored to the cent, so a cent is rounding, not a change.
3. An increase counts as `ESCALATOR` only when both are true:
   - an anniversary of the agreement falls after the earlier statement's due date and on or before the later one's. Anniversaries count from the agreement's first due date, or its start date if that's blank.
   - the increase equals the earlier amount times the agreement's escalator rate, to the cent. For example, $120.00 × 2.90% = $3.48.
4. Anything else, including any decrease: `UNEXPLAINED_CHANGE`.
5. The reason carries the before and after amounts, the difference, and for an escalator the rate and the anniversary date, so the agent can say exactly what happened.

**What can go wrong:** A missing agreement or a missing rate means the increase can't be the escalator, so it's unexplained. The service doesn't assume. An increase of the right size in the wrong month is unexplained too: matching only the amount would explain a billing error away. The rate field is a percent field, so 2.90 means 2.90%.

**How it's tested:** `AmountDueComparisonTest`, all in memory:
- the first anniversary ($120.00 to $123.48), and a later one that compounds and rounds ($123.48 to $127.06)
- the right amount away from the anniversary, the wrong amount at it, a decrease, and no agreement
- a one-cent difference counted as no change, and a first statement
- blank first due date and due date, falling back to the start date and statement date
- anniversary edges: on the later date counts, on the earlier date doesn't count again, and a February 29 agreement keeps its day in leap years
- rate edges: no rate, a zero rate, a decrease
