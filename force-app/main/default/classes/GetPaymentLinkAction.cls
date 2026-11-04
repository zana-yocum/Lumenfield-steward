/**
 * ST-05, ST-12, GR-01, GR-06, S-06. The service agent's way to take a payment: a link to Stripe's
 * secure checkout page for one of the household's statements, for its balance. The customer types
 * card details on Stripe's page, never into the chat, and the agent never sees or repeats a card
 * number (S-06). A statement ID the model passes is looked for only in the logged-in household.
 */
public with sharing class GetPaymentLinkAction {
  private static final String ACTION = 'GetPaymentLinkAction';

  /** One request. */
  public class Input {
    @InvocableVariable(
      label='Messaging Session ID'
      description='Bind to $Context.RoutableId. Never let the model fill this.'
      required=true
    )
    public String sessionId;
    @InvocableVariable(
      label='Statement ID'
      description='A statement ID from Get Account Summary. Leave empty for the oldest statement with a balance.'
    )
    public String statementId;
  }

  /** The link, or the reason there isn't one. */
  public class Output {
    @InvocableVariable(
      label='Outcome'
      description='COMPLETED, DECLINED_POLICY or FAILED'
    )
    public String outcome;
    @InvocableVariable(
      label='Reason Code'
      description='On a decline or failure, why: NOT_VERIFIED, SESSION_ENDED, WRONG_CHANNEL, NOT_FOUND, NOTHING_OWED, PROVIDER_UNAVAILABLE or UNEXPECTED_ERROR'
    )
    public String reasonCode;
    @InvocableVariable(
      label='Reference'
      description='On a failure only: the number the customer can quote to a person'
    )
    public String reference;
    @InvocableVariable(
      label='Payment Link'
      description='Stripe\'s secure checkout page. Send it as it is. It stays open for an hour.'
    )
    public String paymentLink;
    @InvocableVariable(
      label='Amount'
      description='What the page asks for: the statement\'s balance'
    )
    public Decimal amount;
    @InvocableVariable(
      label='Statement Number'
      description='The statement it pays'
    )
    public String statementNumber;
  }

  /**
   * A payment link for each request's statement.
   * @param inputs one per request
   * @return one output per request, in order
   */
  @InvocableMethod(
    label='Get Payment Link'
    description='ST-05. A link to a secure Stripe checkout page for one statement\'s balance. Use when the customer wants to pay, or types card details into the chat: never repeat a card number; send this link instead.'
    category='Steward Service Agent'
  )
  public static List<Output> run(List<Input> inputs) {
    AgentActions.Calls calls = new AgentActions.Calls(
      ACTION,
      sessionIdsOf(inputs)
    );
    List<Integer> sent = new List<Integer>();
    for (Integer i = 0; i < inputs.size(); i++) {
      String statementId = inputs[i]?.statementId;
      String asked =
        'Payment link for statement ' +
        (String.isBlank(statementId) ? '(oldest with a balance)' : statementId);
      if (
        calls.begin(i, new PaymentCheckoutService.Checkout(), asked) &&
        calls.acceptsId(i, statementId)
      ) {
        sent.add(i);
      }
    }
    try {
      AgentActions.failIfSimulated();
      for (Integer i : sent) {
        PaymentCheckoutService.Checkout checkout = PaymentCheckoutService.startCheckout(
          calls.household(i),
          AgentActions.toId(inputs[i].statementId)
        );
        calls.serve(i, checkout);
        calls.logFailureDetail(i, checkout.failureDetail);
      }
    } catch (Exception error) {
      calls.fail(error);
    }
    IntegrationLogger.save();

    List<Output> outputs = new List<Output>();
    for (StewardOutcome.Result result : calls.finish()) {
      outputs.add(toOutput((PaymentCheckoutService.Checkout) result));
    }
    return outputs;
  }

  private static Output toOutput(PaymentCheckoutService.Checkout checkout) {
    Output output = new Output();
    output.outcome = checkout.outcome;
    output.reasonCode = checkout.reasonCode;
    output.reference = checkout.reference;
    output.amount = checkout.amount;
    output.statementNumber = checkout.statementNumber;
    if (checkout.outcome == StewardOutcome.COMPLETED) {
      output.paymentLink = checkout.checkoutUrl;
    }
    return output;
  }

  private static List<String> sessionIdsOf(List<Input> inputs) {
    List<String> sessionIds = new List<String>();
    for (Input input : inputs) {
      sessionIds.add(input?.sessionId);
    }
    return sessionIds;
  }
}
