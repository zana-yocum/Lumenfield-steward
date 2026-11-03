/**
 * ST-04, ST-12, GR-01, GR-03, GR-06. Tells the logged-in customer whether a payment arrangement
 * they describe is one they can set up themselves, without saving anything: eligible, declined by
 * a rule with the figures that rule allows, or handed to a person. PaymentArrangementService
 * checks the same policy records Accord's own flow reads, so the answer matches what a save would
 * do. The agent calls this before it asks the customer to confirm (GR-05).
 */
public with sharing class CheckPaymentArrangementAction {
  private static final String ACTION = 'CheckPaymentArrangementAction';

  /** One arrangement to check. */
  public class Input {
    @InvocableVariable(
      label='Messaging Session ID'
      description='Bind to $Context.RoutableId. Never let the model fill this.'
      required=true
    )
    public String sessionId;
    @InvocableVariable(
      label='Promise Date'
      description='The date the customer says they will pay'
      required=true
    )
    public Date promiseDate;
    @InvocableVariable(
      label='Amount'
      description='What the customer says they will pay, in dollars'
      required=true
    )
    public Decimal amount;
  }

  /** Whether it's allowed, and the figures behind the answer. */
  public class Output {
    @InvocableVariable(
      label='Outcome'
      description='COMPLETED when eligible, DECLINED_POLICY, HANDOFF or FAILED'
    )
    public String outcome;
    @InvocableVariable(
      label='Reason Code'
      description='ELIGIBLE, or why not: DATE_IN_PAST, DATE_OUTSIDE_WINDOW, AMOUNT_BELOW_MINIMUM, EXISTING_PROMISE, NOTHING_PAST_DUE, BROKEN_PROMISE_LIMIT, ACCOUNT_STATUS, NOT_VERIFIED, SESSION_ENDED, WRONG_CHANNEL, NOT_FOUND, INVALID_REQUEST or UNEXPECTED_ERROR'
    )
    public String reasonCode;
    @InvocableVariable(
      label='Reference'
      description='On a failure only: the number the customer can quote to a person'
    )
    public String reference;
    @InvocableVariable(label='Past Due Balance')
    public Decimal pastDueBalance;
    @InvocableVariable(
      label='Minimum Amount'
      description='The least an arrangement set up online may be for'
    )
    public Decimal minimumAmount;
    @InvocableVariable(
      label='Latest Allowed Date'
      description='The latest date an arrangement set up online may be for'
    )
    public Date latestAllowedDate;
    @InvocableVariable(label='Promise Date')
    public Date promiseDate;
    @InvocableVariable(label='Promise Amount')
    public Decimal promiseAmount;
    @InvocableVariable(
      label='Existing Promise Amount'
      description='EXISTING_PROMISE: the promise already in place'
    )
    public Decimal existingPromiseAmount;
    @InvocableVariable(label='Existing Promise Date')
    public Date existingPromiseDate;
    @InvocableVariable(label='Existing Promise Status')
    public String existingPromiseStatus;
  }

  /**
   * Checks each request's arrangement against the policy. Saves nothing.
   * @param inputs one per request
   * @return one output per request, in order
   */
  @InvocableMethod(
    label='Check Payment Arrangement'
    description='ST-04. Whether the logged-in customer can arrange to pay a given amount on a given date themselves, and if not, which rule says no and what it allows. Saves nothing. Use before offering to set one up.'
    category='Steward Service Agent'
  )
  public static List<Output> run(List<Input> inputs) {
    AgentActions.Calls calls = new AgentActions.Calls(
      ACTION,
      sessionIdsOf(inputs)
    );
    List<PaymentArrangementService.Request> requests = new List<PaymentArrangementService.Request>();
    List<Integer> sent = new List<Integer>();
    for (Integer i = 0; i < inputs.size(); i++) {
      Input input = inputs[i];
      String asked =
        'Check arrangement: ' +
        input?.amount +
        ' on ' +
        input?.promiseDate;
      if (
        calls.begin(i, new PaymentArrangementService.ArrangementResult(), asked)
      ) {
        requests.add(
          new PaymentArrangementService.Request(
            calls.household(i),
            input.promiseDate,
            input.amount
          )
        );
        sent.add(i);
      }
    }
    try {
      AgentActions.failIfSimulated();
      calls.serveAll(
        sent,
        PaymentArrangementService.checkEligibility(requests)
      );
    } catch (Exception error) {
      calls.fail(error);
    }

    List<Output> outputs = new List<Output>();
    for (StewardOutcome.Result result : calls.finish()) {
      outputs.add(
        toOutput((PaymentArrangementService.ArrangementResult) result)
      );
    }
    return outputs;
  }

  private static Output toOutput(
    PaymentArrangementService.ArrangementResult result
  ) {
    Output output = new Output();
    output.outcome = result.outcome;
    output.reasonCode = result.reasonCode;
    output.reference = result.reference;
    output.pastDueBalance = result.pastDueBalance;
    output.minimumAmount = result.minimumAmount;
    output.latestAllowedDate = result.latestAllowedDate;
    output.promiseDate = result.promiseDate;
    output.promiseAmount = result.promiseAmount;
    output.existingPromiseAmount = result.existingPromiseAmount;
    output.existingPromiseDate = result.existingPromiseDate;
    output.existingPromiseStatus = result.existingPromiseStatus;
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
