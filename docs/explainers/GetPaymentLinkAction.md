# GetPaymentLinkAction

**What it does:** The service agent's way to take a payment: a link to Stripe's secure checkout page for one of the logged-in household's statements, for its balance.

**Why it exists:** ST-05, ST-12, GR-01, S-06. If a customer types a card number into the chat, the agent shouldn't repeat it or use it. It sends this link instead, and the customer types their card on Stripe's page.

**How it works:**
1. Like every action, it takes the messaging session's ID, bound to `$Context.RoutableId`, never an account. `AgentActions.Calls` declines a chat with no verified customer before anything is read.
2. A statement ID the model passes is checked first: blank, or a well-formed ID. Anything else is `NOT_FOUND` and isn't guessed at, and a card number typed in its place never reaches the log. Blank means the oldest statement with a balance.
3. `PaymentCheckoutService.startCheckout` looks for the statement only in the household, and asks Stripe for the page. That's one call per request.
4. The calls to Stripe are saved, then every request is logged on the action log. A failure carries its log number for the customer to quote.

**Outputs:** outcome, reason code, reference, `paymentLink` (send it as it is; it stays open an hour), amount and statement number.

**What can go wrong:** `NOT_VERIFIED`, `SESSION_ENDED`, `WRONG_CHANNEL`, `NOT_FOUND`, `NOTHING_OWED`, `PROVIDER_UNAVAILABLE` or `UNEXPECTED_ERROR`, each logged.

**How it's tested:**
- `GetPaymentLinkActionTest`:
  - the customer's own balance gets a link, and the request is logged on their household
  - a chat with no customer gets nothing, with Stripe never asked
  - another household's statement is NOT_FOUND
  - a card number in place of a statement ID is refused and kept out of the log
  - Stripe down gives a reference, and so does anything unexpected
- `AgentPaymentAccessTest` runs it as an Einstein Agent User with only the agent's access. That access is enough, and every household is shared to the agent, yet only the chat's customer gets a link.
