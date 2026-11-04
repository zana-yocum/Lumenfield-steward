# customerTimeline

**What it does:** Shows one household's history on one timeline: statements, payments, promises to pay, billing disputes, credits and commitments, newest first. A filter lets the reader pick which kinds to see. It runs in two places:
- In the console, it's the History tab on `Steward_Account_Record_Page`, where every event links to its record.
- On the portal, it's on the My Account page, below the figures. There it always shows the customer's own household, and statements and disputes link to their portal pages.

**Why it exists:** ST-15, ST-12, NFR-05, NFR-07. A rep sees the story of an account instead of six related lists, and a customer sees the same story for their own household only.

**How it works:**
1. On load it calls `CustomerTimelineController.getTimeline` with the record page's `recordId` (empty on the portal) and no kinds, which means every kind. The first answer also says which kinds the person can read, so the filter offers only those, all ticked.
2. Each event shows a heading with its kind and number ("Statement STMT-00012"), its date in a `<time>` element, and only the facts the server sent. A field the person can't read never arrives, so it never shows.
3. Changing the filter reloads from the first page with the ticked kinds. Unticking every kind asks the reader to choose one, without calling the server. If a slow answer arrives for a filter that has since changed, it's ignored.
4. More loads when the end of the list scrolls into view, through an `IntersectionObserver`. **Show more** does the same for keyboard and screen-reader users, and anywhere the browser can't watch. After Show more, focus moves to the first new event's heading, so a keyboard user carries on from there.
5. A count under the list says how many events are shown and whether more can load. It's a polite live region, so a screen reader announces each new page.

**What can go wrong:**
- A server failure shows "The history couldn't load" with a reference to quote, never the error. A lost connection gets its own message.
- In the console, an account that isn't a household says history is kept for household accounts. On the portal, no household says the history isn't available.
- If the next page fails, the list stays, the message appears under it, and Show more stays there to try again.
- Empty states are separate: no history yet, nothing of the chosen kinds, and nothing shared with this person.

**Accessibility (WCAG 2.2 AA):** The section is a region named by its heading. The filter is a fieldset with a legend, and each kind is a real checkbox with its label, at least 24 pixels tall. Events are an ordered list with a heading each. Status and kind are always written out, never shown by color. Every color, size and space comes from `portalStyles`' tokens, each set from an SLDS styling hook.

**How it's tested:** `customerTimeline.test.js`, 17 tests:
- The loaded state, with the facts to the cent and the dates.
- Console links on every event, and portal links on statements and disputes only.
- A missing fact and a missing date.
- The empty, no-access and nothing-chosen states.
- A failure with its reference, and a lost connection.
- Not a household in the console, and not available on the portal.
- Filtering, and a stale answer ignored.
- Show more moving focus, a failed next page keeping the list, and loading on scroll.

Each state passes the accessibility check. `portalMyAccount.test.js` checks the timeline appears under the figures, and not when the account fails to load.
