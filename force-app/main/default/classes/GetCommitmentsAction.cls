/**
 * ST-02, ST-12, S-08, GR-01, GR-06. The service agent's answer to "what did you promise me when I
 * signed?": the commitments recorded on the logged-in customer's deal, the five fields a customer
 * may see, from CommitmentReadService. The household comes from the chat's session
 * (AgentSession), and every request is logged.
 */
public with sharing class GetCommitmentsAction {
  private static final String ACTION = 'GetCommitmentsAction';

  /** One request. */
  public class Input {
    @InvocableVariable(
      label='Messaging Session ID'
      description='Bind to $Context.RoutableId. Never let the model fill this.'
      required=true
    )
    public String sessionId;
  }

  /** The household's commitments, or the reason there are none. */
  public class Output {
    @InvocableVariable(
      label='Outcome'
      description='COMPLETED, DECLINED_POLICY or FAILED'
    )
    public String outcome;
    @InvocableVariable(
      label='Reason Code'
      description='NONE_RECORDED when nothing was promised; on a decline or failure, why: NOT_VERIFIED, SESSION_ENDED, WRONG_CHANNEL, NOT_FOUND or UNEXPECTED_ERROR'
    )
    public String reasonCode;
    @InvocableVariable(
      label='Reference'
      description='On a failure only: the number the customer can quote to a person'
    )
    public String reference;
    @InvocableVariable(
      label='Commitments'
      description='Each one\'s type, value, months covered, terms as the rep recorded them, and status'
    )
    public List<CommitmentReadService.CommitmentView> commitments;
  }

  /**
   * The commitments for each request's household.
   * @param inputs one per request
   * @return one output per request, in order
   */
  @InvocableMethod(
    label='Get Commitments'
    description='ST-02. What Lumenfield promised the logged-in customer when they signed: credits, covered payments, delayed billing. Use when they say they were promised something.'
    category='Steward Service Agent'
  )
  public static List<Output> run(List<Input> inputs) {
    AgentActions.Calls calls = new AgentActions.Calls(
      ACTION,
      sessionIdsOf(inputs)
    );
    for (Integer i = 0; i < calls.count(); i++) {
      calls.begin(
        i,
        new CommitmentReadService.HouseholdCommitments(),
        'Commitments from signing'
      );
    }
    try {
      AgentActions.failIfSimulated();
      Map<Id, CommitmentReadService.HouseholdCommitments> found = CommitmentReadService.forHouseholds(
        calls.households()
      );
      for (Integer i = 0; i < calls.count(); i++) {
        calls.serve(i, found.get(calls.household(i)));
      }
    } catch (Exception error) {
      calls.fail(error);
    }

    List<Output> outputs = new List<Output>();
    for (StewardOutcome.Result result : calls.finish()) {
      outputs.add(
        toOutput((CommitmentReadService.HouseholdCommitments) result)
      );
    }
    return outputs;
  }

  private static Output toOutput(
    CommitmentReadService.HouseholdCommitments household
  ) {
    Output output = new Output();
    output.outcome = household.outcome;
    output.reasonCode = household.reasonCode;
    output.reference = household.reference;
    if (household.outcome == StewardOutcome.COMPLETED) {
      output.commitments = household.commitments;
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
