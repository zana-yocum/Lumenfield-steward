/**
 * ST-06, ST-12, GR-01, GR-02, GR-05, GR-06, S-14. Opens the billing dispute the logged-in customer
 * confirmed, on one of their own statements, and returns the case number with the evidence to
 * send, required items first. DisputeIntakeService saves the case and Accord takes over: its flows
 * start the SLA clock and flag the statement, and its assignment rule routes the case to the
 * dispute specialists. A statement ID the model passes is looked for only in the household
 * (ST-12). The agent reaches this action only after the customer has confirmed the statement and
 * the reason (GR-05, in the agent's script).
 */
public with sharing class OpenDisputeAction {
  private static final String ACTION = 'OpenDisputeAction';

  /** One dispute the customer confirmed. */
  public class Input {
    @InvocableVariable(
      label='Messaging Session ID'
      description='Bind to $Context.RoutableId. Never let the model fill this.'
      required=true
    )
    public String sessionId;
    @InvocableVariable(
      label='Statement ID'
      description='The disputed statement\'s ID, from Get Account Summary'
      required=true
    )
    public String statementId;
    @InvocableVariable(
      label='Dispute Reason'
      description='One reason value from Get Dispute Reasons, exactly as given'
      required=true
    )
    public String reason;
    @InvocableVariable(
      label='Description'
      description='What the customer said about the problem, in their words. Optional. Card numbers are removed before saving.'
    )
    public String description;
  }

  /** The new dispute, or why there isn't one. */
  public class Output {
    @InvocableVariable(
      label='Outcome'
      description='COMPLETED when opened, DECLINED_POLICY or FAILED'
    )
    public String outcome;
    @InvocableVariable(
      label='Reason Code'
      description='Why it wasn\'t opened: EXISTING_DISPUTE (caseNumber is the open one), INVALID_REASON, STATEMENT_REQUIRED, NOT_FOUND, ACCESS_DENIED, SAVE_FAILED, NOT_VERIFIED, SESSION_ENDED, WRONG_CHANNEL or UNEXPECTED_ERROR'
    )
    public String reasonCode;
    @InvocableVariable(
      label='Reference'
      description='On a failure only: the number the customer can quote to a person'
    )
    public String reference;
    @InvocableVariable(
      label='Case Number'
      description='The new dispute, or the one already open on the statement'
    )
    public String caseNumber;
    @InvocableVariable(label='Case Status')
    public String caseStatus;
    @InvocableVariable(label='Dispute Reason')
    public String reason;
    @InvocableVariable(
      label='Evidence'
      description='What the customer needs to send for this reason, required items first'
    )
    public List<AgentActions.EvidenceLine> evidence;
  }

  /**
   * Opens each confirmed dispute that passes Accord's checks.
   * @param inputs one per request
   * @return one output per request, in order
   */
  @InvocableMethod(
    label='Open Dispute'
    description='ST-06. Opens a billing dispute on one of the logged-in customer\'s statements, after they have confirmed the statement and the reason, and returns the case number and the evidence to send.'
    category='Steward Service Agent'
  )
  public static List<Output> run(List<Input> inputs) {
    AgentActions.Calls calls = new AgentActions.Calls(
      ACTION,
      sessionIdsOf(inputs)
    );
    List<Integer> sent = new List<Integer>();
    List<DisputeIntakeService.Request> disputes = new List<DisputeIntakeService.Request>();
    for (Integer i = 0; i < inputs.size(); i++) {
      Input input = inputs[i];
      String asked =
        'Open dispute: ' +
        input?.reason +
        ' on statement ' +
        input?.statementId;
      if (
        calls.begin(i, new DisputeIntakeService.DisputeResult(), asked) &&
        calls.acceptsId(i, input.statementId)
      ) {
        sent.add(i);
        disputes.add(requestFor(calls.household(i), input));
      }
    }
    open(calls, sent, disputes);

    List<Output> outputs = new List<Output>();
    for (StewardOutcome.Result result : calls.finish()) {
      outputs.add(toOutput((DisputeIntakeService.DisputeResult) result));
    }
    return outputs;
  }

  private static DisputeIntakeService.Request requestFor(
    Id household,
    Input input
  ) {
    DisputeIntakeService.Request request = new DisputeIntakeService.Request(
      household,
      AgentActions.toId(input.statementId),
      input.reason
    );
    request.description = input.description;
    return request;
  }

  /**
   * Opens the disputes in one call. An exception rolls every one of them back, so nothing
   * half-saved stays behind an error the customer is told about.
   * @param calls the action's requests
   * @param sent the positions of the requests sent on, in order
   * @param disputes their service requests, in the same order
   */
  private static void open(
    AgentActions.Calls calls,
    List<Integer> sent,
    List<DisputeIntakeService.Request> disputes
  ) {
    Savepoint beforeSave = Database.setSavepoint();
    try {
      AgentActions.failIfSimulated();
      List<DisputeIntakeService.DisputeResult> opened = DisputeIntakeService.openDisputes(
        disputes
      );
      for (Integer q = 0; q < sent.size(); q++) {
        calls.serve(sent[q], opened[q]);
        calls.logFailureDetail(sent[q], opened[q].failureDetail);
      }
    } catch (Exception error) {
      Database.rollback(beforeSave);
      calls.fail(error);
    }
  }

  private static Output toOutput(DisputeIntakeService.DisputeResult result) {
    Output output = new Output();
    output.outcome = result.outcome;
    output.reasonCode = result.reasonCode;
    output.reference = result.reference;
    output.caseNumber = result.caseNumber;
    output.caseStatus = result.caseStatus;
    output.reason = result.reason;
    output.evidence = AgentActions.evidenceLines(result.evidence);
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
