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
    List<String> sessionIds = new List<String>();
    for (Input input : inputs) {
      sessionIds.add(input?.sessionId);
    }
    Map<String, AgentSession.Identity> identities = AgentActions.identities(
      sessionIds
    );

    List<DisputeIntakeService.DisputeResult> results = new List<DisputeIntakeService.DisputeResult>();
    List<DisputeIntakeService.Request> requests = new List<DisputeIntakeService.Request>();
    List<Integer> queued = new List<Integer>();
    for (Integer i = 0; i < inputs.size(); i++) {
      AgentSession.Identity identity = identities.get(sessionIds[i]);
      String statementId = inputs[i]?.statementId;
      DisputeIntakeService.DisputeResult result = new DisputeIntakeService.DisputeResult();
      if (!identity.isVerified()) {
        AgentActions.declineUnverified(result, identity);
      } else if (
        String.isNotBlank(statementId) && AgentActions.toId(statementId) == null
      ) {
        AgentActions.declineNotFound(result);
      } else {
        DisputeIntakeService.Request request = new DisputeIntakeService.Request(
          identity.accountId,
          AgentActions.toId(statementId),
          inputs[i]?.reason
        );
        request.description = inputs[i]?.description;
        requests.add(request);
        queued.add(i);
      }
      results.add(result);
    }

    String failure;
    Savepoint beforeSave = Database.setSavepoint();
    try {
      AgentActions.failIfSimulated();
      List<DisputeIntakeService.DisputeResult> opened = DisputeIntakeService.openDisputes(
        requests
      );
      for (Integer q = 0; q < queued.size(); q++) {
        results[queued[q]] = opened[q];
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
      DisputeIntakeService.DisputeResult result = results[i];
      String details;
      if (failure != null && result.outcome == StewardOutcome.FAILED) {
        details = failure;
      } else if (result.failureDetail != null) {
        details = result.failureDetail;
      } else {
        details =
          'Open dispute: ' +
          inputs[i]?.reason +
          ' on statement ' +
          inputs[i]?.statementId;
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
    for (DisputeIntakeService.DisputeResult result : results) {
      Output output = new Output();
      output.outcome = result.outcome;
      output.reasonCode = result.reasonCode;
      output.reference = result.reference;
      output.caseNumber = result.caseNumber;
      output.caseStatus = result.caseStatus;
      output.reason = result.reason;
      output.evidence = AgentActions.evidenceLines(result.evidence);
      outputs.add(output);
    }
    return outputs;
  }
}
