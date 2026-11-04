# PortalLinks

**What it does:** Builds the address of a statement's own portal page, `…/portal/statement?recordId=…`. It's used for links that leave Salesforce and come back, such as where Stripe sends a customer after paying.

**Why it exists:** ST-05. The return address has to work wherever the checkout started: on the portal, in the agent's chat, or from a scheduled job.

**How it works:**
1. **On the portal:** the address comes from the site itself (`Site.getBaseUrl()`).
2. **Elsewhere:** it's worked out from the org's My Domain. With enhanced domains, which Salesforce enforces, a site lives at `<my domain>.my.site.com` when the org lives at `<my domain>.my.salesforce.com`. The portal's path, `portal`, comes from `digitalExperienceConfigs`.

**What can go wrong:** A custom domain on the site would only show up through `Site.getBaseUrl()`. The agent and the job would still build the default domain, which keeps working alongside a custom one.

**How it's tested:** `PortalLinksTest`. Outside the site, the address is on the site domain, never the org's own, and ends with the statement page and its ID.
