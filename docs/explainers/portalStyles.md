# portalStyles

**What it does:** The portal's shared stylesheet: one set of tokens for every color, size and space, and the classes every page uses (page, titles, cards, lists, details, notices, links and focus). Components bring it in with `@import "c/portalStyles";`.

**Why it exists:** NFR-05 and docs/conventions.md: styling comes from SLDS styling hooks only, with no hard-coded colors, so contrast is checked once, at the source.

**How it works:**
1. The tokens are set on `:host`, so each component that imports the sheet gets them. Each one names an SLDS global styling hook, such as `--portal-color-link: var(--slds-g-color-accent-2, #0b5cab)`. The value after the hook is used only where the site doesn't define it, so the portal looks right either way.
2. The one value with no SLDS hook, the page's maximum width, is a named token too, so no component hard-codes a size.
3. The classes keep one column on a 360-pixel phone, show details in a two-column grid that becomes three on a wider screen, and give every link and focusable heading a visible focus ring.
4. Status is always written out in words. Borders and color only frame it.

**What can go wrong:** If a site's theme sets an SLDS hook to a color with poor contrast, the portal inherits it. The hooks chosen are the ones SLDS defines for text, links and borders on a light surface.

**How it's tested:** Code Analyzer's SLDS rules report nothing on the portal's stylesheets, and every component's Jest tests run an accessibility check (`toBeAccessible`). The site's look is checked by eye in the walkthrough.
