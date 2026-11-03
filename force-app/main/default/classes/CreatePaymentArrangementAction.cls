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
    List<String> sessionIds = new List<String>();
    for (Input input : inputs) {
      sessionIds.add(input?.sessionId);
    }
    Map<String, AgentSession.Identity> identities = AgentActions.identities(
      sessionIds
    );

    List<PaymentArrangementService.ArrangementResult> results = new List<PaymentArrangementService.ArrangementResult>();
    List<PaymentArrangementService.Request> requests = new List<PaymentArrangementService.Request>();
    List<Integer> queued = new List<Integer>();
    for (Integer i = 0; i < inputs.size(); i++) {
      AgentSession.Identity identity = identities.get(sessionIds[i]);
      PaymentArrangementService.ArrangementResult result = new PaymentArrangementService.ArrangementResult();
      if (identity.isVerified()) {
        requests.add(
          new PaymentArrangementService.Request(
            identity.accountId,
            inputs[i]?.promiseDate,
            inputs[i]?.amount
          )
        );
        queued.add(i);
      } else {
        AgentActions.declineUnverified(result, identity);
      }
      results.add(result);
    }

    String failure;
    Savepoint beforeSave = Database.setSavepoint();
    try {
      AgentActions.failIfSimulated();
      List<PaymentArrangementService.ArrangementResult> created = PaymentArrangementService.createArrangements(
        requests
      );
      for (Integer q = 0; q < queued.size(); q++) {
        results[queued[q]] = created[q];
      }
    } catch (Exception error) {
      // Nothing half-saved stays behind an error the customer is told about.
      Database.rollback(beforeSave);
      failure = AgentActions.describe(error);
      for (Integer i : queued) {
        AgentActions.markFailed(results[i]);
      }
    }

    List<AgentActionLogger.Entry> entries = new List<AgentActionLogger.Entry>();
    for (Integer i = 0; i < inputs.size(); i++) {
      PaymentArrangementService.ArrangementResult result = results[i];
      String details;
      if (failure != null && result.outcome == StewardOutcome.FAILED) {
        details = failure;
      } else if (result.failureDetail != null) {
        details = result.failureDetail;
      } else {
        details =
          'Create arrangement: ' +
          inputs[i]?.amount +
          ' on ' +
          inputs[i]?.promiseDate;
      }
      entries.add(
        AgentActions.entry(
          identities.get(sessionIds[i]),
          ACTION,
          result,
          details
        )
      );
    }
    AgentActions.log(entries, results);

    List<Output> outputs = new List<Output>();
    for (PaymentArrangementService.ArrangementResult result : results) {
      outputs.add(toOutput(result));
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
}
