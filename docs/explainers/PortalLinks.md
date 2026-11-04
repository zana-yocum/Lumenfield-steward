# PortalLinks

**What it does:** Builds the address of a statement's own portal page, `…/portal/statement?recordId=…`. It's used for links that leave Salesforce and come back, such as where Stripe sends a customer after paying.

**Why it exists:** ST-05. The return address has to work wherever the checkout started: on the portal, in the agent's chat, or from a scheduled job.

**How it works:**
1. The address is always worked out from the org's My Domain. With enhanced domains, which Salesforce enforces, a site lives at `<my domain>.my.site.com` when the org lives at `<my domain>.my.salesforce.com`.
2. The portal's path, `portal`, comes from `digitalExperienceConfigs`. Checked in the org on 2026-11-04: the LWR site is at `….develop.my.site.com/portal`.
3. It doesn't ask the site for its address (`Site.getBaseUrl`). An LWR site has a Visualforce companion at its own path, `/portalvforcesite` in this org, and a link there would leave the customer outside the portal. One rule for every caller is also one rule to test.

**What can go wrong:** A custom domain on the site isn't used: the links stay on the `my.site.com` domain, which keeps working alongside a custom one. If the portal's path ever changes, `PORTAL_PATH` changes with it.

**How it's tested:** `PortalLinksTest`: the address is on the site domain, never the org's own or the Visualforce companion's, and ends with the statement page and its ID.
