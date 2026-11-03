/**
 * ST-04, ST-12, GR-01, GR-02, GR-03, GR-05, GR-06. Sets up the payment arrangement the logged-in
 * customer confirmed: an Active promise to pay, saved through Accord's flow, which puts the account
 * on hold until the grace date. PaymentArrangementService checks the policy again before saving,
 * and rolls the save back if Accord's flow would send it for approval, so the agent never leaves
 * anything for a supervisor to approve (GR-03). The agent reaches this action only after the
 * customer has said yes to the exact amount and date (GR-05, in the agent's script).
 */
public with sharing class CreatePaymentArrangementAction {
  private static final String ACTION = 'CreatePaymentArrangementAction';

  /** One arrangement the customer confirmed. */
  public class Input {
    @InvocableVariable(
      label='Messaging Session ID'
      description='Bind to $Context.RoutableId. Never let the model fill this.'
      required=true
    )
    public String sessionId;
    @InvocableVariable(
      label='Promise Date'
      description='The date the customer confirmed they will pay'
      required=true
    )
    public Date promiseDate;
    @InvocableVariable(
      label='Amount'
      description='The amount the customer confirmed they will pay, in dollars'
      required=true
    )
    public Decimal amount;
  }

  /** The new promise, or why there isn't one. */
  public class Output {
    @InvocableVariable(
      label='Outcome'
      description='COMPLETED when saved, DECLINED_POLICY, HANDOFF or FAILED'
    )
    public String outcome;
    @InvocableVariable(
      label='Reason Code'
      description='Why it wasn\'t saved: the same codes as Check Payment Arrangement, plus WOULD_NEED_APPROVAL and SAVE_FAILED'
    )
    public String reasonCode;
    @InvocableVariable(
      label='Reference'
      description='On a failure only: the number the customer can quote to a person'
    )
    public String reference;
    @InvocableVariable(label='Promise Number')
    public String promiseNumber;
    @InvocableVariable(label='Promise Status')
    public String promiseStatus;
    @InvocableVariable(label='Promise Date')
    public Date promiseDate;
    @InvocableVariable(label='Promise Amount')
    public Decimal promiseAmount;
    @InvocableVariable(
      label='Hold Until'
      description='Collections activity pauses until this date: the promise date plus the grace days'
    )
    public Date holdUntil;
    @InvocableVariable(label='Past Due Balance')
    public Decimal pastDueBalance;
    @InvocableVariable(label='Minimum Amount')
    public Decimal minimumAmount;
    @InvocableVariable(label='Latest Allowed Date')
    public Date latestAllowedDate;
    @InvocableVariable(label='Existing Promise Amount')
    public Decimal existingPromiseAmount;
    @InvocableVariable(label='Existing Promise Date')
    public Date existingPromiseDate;
    @InvocableVariable(label='Existing Promise Status')
    public String existingPromiseStatus;
  }

  /**
   * Saves each confirmed arrangement the policy allows.
   * @param inputs one per request
   * @return one output per request, in order
   */
  @InvocableMethod(
    label='Create Payment Arrangement'
    description='ST-04. Saves a promise to pay for the logged-in customer, after they have confirmed the exact amount and date. Only after Check Payment Arrangement said ELIGIBLE and the customer said yes.'
    category='Steward Service Agent'
  )
  public static List<Output> run(List<Input> inputs) {
    AgentActions.Calls calls = new AgentActions.Calls(
      ACTION,
      sessionIdsOf(inputs)
    );
    List<Integer> confirmed = new List<Integer>();
    List<PaymentArrangementService.Request> arrangements = new List<PaymentArrangementService.Request>();
    for (Integer i = 0; i < inputs.size(); i++) {
      Input input = inputs[i];
      String asked =
        'Create arrangement: ' +
        input?.amount +
        ' on ' +
        input?.promiseDate;
      if (
        calls.begin(i, new PaymentArrangementService.ArrangementResult(), asked)
      ) {
        confirmed.add(i);
        arrangements.add(
          new PaymentArrangementService.Request(
            calls.household(i),
            input.promiseDate,
            input.amount
          )
        );
      }
    }
    save(calls, confirmed, arrangements);

    List<Output> outputs = new List<Output>();
    for (StewardOutcome.Result result : calls.finish()) {
      outputs.add(
        toOutput((PaymentArrangementService.ArrangementResult) result)
      );
    }
    return outputs;
  }

  /**
   * Saves the confirmed arrangements in one call. An exception rolls every one of them back, so
   * nothing half-saved stays behind an error the customer is told about.
   * @param calls the action's requests
   * @param confirmed the positions of the requests sent on, in order
   * @param arrangements their service requests, in the same order
   */
  private static void save(
    AgentActions.Calls calls,
    List<Integer> confirmed,
    List<PaymentArrangementService.Request> arrangements
  ) {
    Savepoint beforeSave = Database.setSavepoint();
    try {
      AgentActions.failIfSimulated();
      List<PaymentArrangementService.ArrangementResult> created = PaymentArrangementService.createArrangements(
        arrangements
      );
      for (Integer q = 0; q < confirmed.size(); q++) {
        calls.serve(confirmed[q], created[q]);
        calls.logFailureDetail(confirmed[q], created[q].failureDetail);
      }
    } catch (Exception error) {
      Database.rollback(beforeSave);
      calls.fail(error);
    }
  }

  private static Output toOutput(
    PaymentArrangementService.ArrangementResult result
  ) {
    Output output = new Output();
    output.outcome = result.outcome;
    output.reasonCode = result.reasonCode;
    output.reference = result.reference;
    output.promiseNumber = result.promiseNumber;
    output.promiseStatus = result.promiseStatus;
    output.promiseDate = result.promiseDate;
    output.promiseAmount = result.promiseAmount;
    output.holdUntil = result.holdUntil;
    output.pastDueBalance = result.pastDueBalance;
    output.minimumAmount = result.minimumAmount;
    output.latestAllowedDate = result.latestAllowedDate;
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
