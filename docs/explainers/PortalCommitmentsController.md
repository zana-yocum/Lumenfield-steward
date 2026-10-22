# PortalCommitmentsController

**What it does:** Serves the portal's What we promised you page: the commitments recorded on the logged-in household's agreement at signing, five fields each.

**Why it exists:** ST-02, S-08, ST-12. Commitments are detail records of the opportunity, and customer licenses can't be given opportunity access. Phase 3's `CommitmentReadService` is the one narrow way through. This controller only finds the household and asks it.

**How it works:**
1. `getMyCommitments()` gets the household from `PortalHousehold` and returns `CommitmentReadService.forHousehold` for it: type, value, months covered, terms and status.
2. The opportunity, its amount and stage, the sales rep and who recorded the commitment are never selected by the service, so they can't reach the page.
3. An exception goes to `PortalFailure`, and the customer gets a reference to quote.

**What can go wrong:** A household with no commitments gets `NONE_RECORDED`, and the page says no special terms were recorded and offers a dispute. A user with no household gets `INVALID_REQUEST`.

**How it's tested:** `PortalControllersTest`. A customer gets only their own household's commitment, with its terms exactly as recorded, while another household's stays out. The service's own scoping tests are in `CommitmentReadServiceTest`.
