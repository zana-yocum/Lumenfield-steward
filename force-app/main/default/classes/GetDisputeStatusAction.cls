/**
 * ST-06, ST-12, GR-01, GR-06. The service agent's answer to "where is my dispute?": the logged-in
 * customer's billing disputes, open and closed, newest first, with each one's status, reason and
 * statement, from DisputeStatusService. Only billing disputes: Accord's Default Reviews on the
 * same account never appear.
 */
public with sharing class GetDisputeStatusAction {
  private static final String ACTION = 'GetDisputeStatusAction';

  /** One request. */
  public class Input {
    @InvocableVariable(
      label='Messaging Session ID'
      description='Bind to $Context.RoutableId. Never let the model fill this.'
      required=true
    )
    public String sessionId;
  }

  /** The household's disputes, or why there are none. */
  public class Output {
    @InvocableVariable(
      label='Outcome'
      description='COMPLETED, DECLINED_POLICY or FAILED'
    )
    public String outcome;
    @InvocableVariable(
      label='Reason Code'
      description='On a decline or failure, why: NOT_VERIFIED, SESSION_ENDED, WRONG_CHANNEL, NOT_FOUND or UNEXPECTED_ERROR'
    )
    public String reasonCode;
    @InvocableVariable(
      label='Reference'
      description='On a failure only: the number the customer can quote to a person'
    )
    public String reference;
    @InvocableVariable(
      label='Disputes'
      description='Each dispute\'s case number, status, whether it is closed, reason, statement and the date it was opened'
    )
    public List<DisputeStatusService.DisputeView> disputes;
  }

  /**
   * The disputes for each request's household.
   * @param inputs one per request
   * @return one output per request, in order
   */
  @InvocableMethod(
    label='Get Dispute Status'
    description='ST-06. The logged-in customer\'s billing disputes and where each one stands. Use when they ask about a dispute they opened.'
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
    Set<Id> households = new Set<Id>();
    for (AgentSession.Identity identity : identities.values()) {
      if (identity.isVerified()) {
        households.add(identity.accountId);
      }
    }

    Map<Id, DisputeStatusService.HouseholdDisputes> found;
    String failure;
    try {
      AgentActions.failIfSimulated();
      found = DisputeStatusService.forHouseholds(households);
    } catch (Exception error) {
      failure = AgentActions.describe(error);
    }

    List<DisputeStatusService.HouseholdDisputes> results = new List<DisputeStatusService.HouseholdDisputes>();
    List<AgentActionLogger.Entry> entries = new List<AgentActionLogger.Entry>();
    for (String sessionId : sessionIds) {
      AgentSession.Identity identity = identities.get(sessionId);
      DisputeStatusService.HouseholdDisputes result;
      String details = 'Dispute status';
      if (!identity.isVerified()) {
        result = new DisputeStatusService.HouseholdDisputes();
        AgentActions.declineUnverified(result, identity);
      } else if (failure != null) {
        result = new DisputeStatusService.HouseholdDisputes();
        AgentActions.markFailed(result);
        details = failure;
      } else {
        result = found.get(identity.accountId);
      }
      results.add(result);
      entries.add(AgentActions.entry(identity, ACTION, result, details));
    }
    AgentActions.log(entries, results);

    List<Output> outputs = new List<Output>();
    for (DisputeStatusService.HouseholdDisputes result : results) {
      Output output = new Output();
      output.outcome = result.outcome;
      output.reasonCode = result.reasonCode;
      output.reference = result.reference;
      if (result.outcome == StewardOutcome.COMPLETED) {
        output.disputes = result.disputes;
      }
      outputs.add(output);
    }
    return outputs;
  }
}
