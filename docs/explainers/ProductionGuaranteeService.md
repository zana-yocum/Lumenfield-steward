# ProductionGuaranteeService

**What it does:** Measures each household's last 12 complete months of solar production against its guarantee, `Production_Guarantee_Pct` (90%) of its agreement's estimated annual production. For a household short of it, `review` opens a **Production Review** holding the measure, with a Draft **Production Guarantee** credit for the shortfall, which goes through Accord's credit approval like any other credit.

**Why it exists:** ST-14, S-29. A dispute specialist should hear about a system that underproduced before the customer has to dispute it, and the credit should follow the same rules as every other credit.

**How it works:**
1. **The window** is the 12 complete months before the day it runs. Run on 2026-11-15, it covers 2025-11-01 to 2026-10-31.
2. **Whose:** only households the caller can see (`HouseholdScope`), each measured against its newest agreement.
3. **The readings** come from a `Readings` source: each agreement's total kWh over the window and how many months had a reading. Data 360 is the source in the org once it's set up (S-29). Until then the default has no readings, so nothing is reviewed. Tests set their own.
4. **The measure, for each household:**
   - no estimate on the agreement: `NO_ESTIMATE`, nothing to measure against
   - fewer than 12 months of readings: `NOT_ENOUGH_READINGS`, so a partial year never opens a review
   - at or above the guarantee: `GUARANTEE_MET`
   - below it: `SHORTFALL`, with the shortfall in kWh, the rate per kWh (a year of monthly payments over the estimate) and the credit (shortfall times rate, to the cent)
5. **The review**, for each shortfall not already reviewed for that agreement and period:
   - a Draft credit on the household, on its newest statement that's open, past due or in dispute, or on none
   - a `Production_Review__c` with the measure, linked to the credit, keyed by agreement and period
   - a shortfall worth nothing at the agreement's rate, such as one with no monthly payment recorded, gets a review without a credit, for a specialist to work out
6. **Accord takes the credit from there.** A credit within the rep limit ($100) posts at once; a larger one waits for a specialist to submit it for approval.

**What can go wrong:** Running the review twice opens nothing new: the review key is unique. The credit is saved with the caller's own access, so a user who can't create credits gets an error rather than a credit they shouldn't make. The review itself is written in system mode (S-29), like the logs: people only read reviews, so nobody needs create on them. A review that can't be saved rolls back its credit with it.

**How it's tested:** `ProductionGuaranteeServiceTest`, with known readings:
- a household 1,000 kWh short gets one review and a $144.00 Draft credit on its past-due statement, and the households that met the guarantee, had 11 months, or had no estimate get nothing
- the window asked for is 12 complete months, ending last month
- a second run opens nothing
- a $43.20 credit is posted by Accord at once
- a shortfall with no monthly payment gets a review without a credit
- a user who can't see the households measures nothing
- with no readings source, nothing is reviewed
- 200 households are reviewed in one run
