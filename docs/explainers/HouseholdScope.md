# HouseholdScope

**What it does:** Answers one question for every Steward service: of these account IDs, which are households the running user can actually see? A household is a Residential Agreement account.

**Why it exists:** ST-12, GR-01, S-07. The worst thing an AI agent could do here is read or change someone else's household. Every service asks `HouseholdScope` first, so the check is written once and tested once instead of being repeated, slightly differently, in every service.

**How it works:**
1. `visibleHouseholds` takes a set of account IDs and drops nulls.
2. It runs one query in user mode: Residential Agreement accounts among those IDs. User mode applies the caller's sharing and object access, so the platform decides what's visible, not Steward.
3. It returns the IDs that came back. Anything else, whether it doesn't exist, belongs to another household or is an Organization account, gets the same answer from every service: `NOT_FOUND`.
4. `isVisible` is the one-ID version.

**What can go wrong:** Nothing is thrown. A null or empty input returns an empty set, and the service reports `INVALID_REQUEST` or `NOT_FOUND`. If the caller has no Account access at all, the user-mode query fails loudly rather than returning data it shouldn't.

**How it's tested:** `HouseholdScopeTest`. An Organization account is never a household. Null, empty and null-only inputs reach nothing. The key test runs as a user who can't see the household: knowing its ID isn't enough. The same user can see it once the account is shared with them. Sharing decides, not the ID.
