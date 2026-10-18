# CommitmentReadService

**What it does:** Returns the commitments recorded at signing for a household, such as "Lumenfield covers the first two monthly payments", as five fields only: type, value, months covered, terms and status.

**Why it exists:** ST-02, ST-12, S-08. A customer should see what they were promised, so nobody has to rely on memory of what a salesperson said. But commitments are detail records of the opportunity, so reading one normally needs access to the opportunity. Customer licenses can't be given opportunity access, and customers shouldn't see the deal anyway. This service is the narrow way through.

**How it works:**
1. **The gate, in user mode.** `HouseholdScope` decides which requested households the caller can see. The rest are `NOT_FOUND`, and nothing is read for them.
2. **The elevated read.** For visible households only, an inner `Elevated` class reads commitments without sharing and in system mode (S-08), filtered on `Commitment__c.Account__c`, the lookup Accord added in DEF-07. It selects only the five customer fields, plus the account to group them by.
3. **Nothing else leaves.** Each commitment is copied into a `CommitmentView` with exactly five properties. The opportunity, its amount and stage, the sales rep and who recorded the commitment are never selected, so they can't leak later through a careless change to the view.
4. A visible household with no commitments gets `NONE_RECORDED`, which is the agent's cue to say no such term is on record and offer a Promised Credit Not Applied dispute.

**What can go wrong:** Knowing a household's ID isn't enough: if the user-mode gate doesn't show it, the elevated read never runs for it. A null ID is `INVALID_REQUEST`. This is one of three named exceptions to user mode in Steward (with S-09 and S-14). It's kept to one query in one inner class, and the class comment cites the decision.

**How it's tested:** `CommitmentReadServiceTest`, the scoping tests the decision asks for:
- a household gets only its own commitments, in type order
- each result has exactly the five fields
- a household with none gets `NONE_RECORDED`
- a user who can't see the household gets `NOT_FOUND` and nothing is read
- the key test: a user with no access to commitments or opportunities, given read access to one household, gets that household's commitments through the service. In the same run, the same user's own user-mode query on `Commitment__c` is blocked, and a second household in the same call stays `NOT_FOUND`.

200 households are read with two queries.
