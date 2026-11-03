/**
 * ST-06, GR-04, GR-06. The eight reasons a customer can dispute a statement for, each with the
 * evidence it needs, required items first, from Accord's own checklist (DisputeEvidenceCatalog).
 * The agent uses it to match what the customer says to a reason, and to tell them what to send.
 * Nothing in it is household data, but the chat must still have a logged-in customer behind it,
 * and every request is logged like any other action.
 */
public with sharing class GetDisputeReasonsAction {
  private static final String ACTION = 'GetDisputeReasonsAction';

  /** One request. */
  public class Input {
    @InvocableVariable(
      label='Messaging Session ID'
      description='Bind to $Context.RoutableId. Never let the model fill this.'
      required=true
    )
    public String sessionId;
  }

  /** The reasons, or why there are none. */
  public class Output {
    @InvocableVariable(
      label='Outcome'
      description='COMPLETED, DECLINED_POLICY or FAILED'
    )
    public String outcome;
    @InvocableVariable(
      label='Reason Code'
      description='On a decline or failure, why: NOT_VERIFIED, SESSION_ENDED, WRONG_CHANNEL or UNEXPECTED_ERROR'
    )
    public String reasonCode;
    @InvocableVariable(
      label='Reference'
      description='On a failure only: the number the customer can quote to a person'
    )
    public String reference;
    @InvocableVariable(
      label='Dispute Reasons'
      description='Each reason\'s value (pass it to Open Dispute exactly), its label, and its evidence, required items first'
    )
    public List<DisputeReason> reasons;
  }

  /** One dispute reason and what the customer needs to send for it. */
  public class DisputeReason {
    @AuraEnabled
    public String value;
    @AuraEnabled
    public String label;
    @AuraEnabled
    public List<AgentActions.EvidenceLine> evidence;
  }

  /** The answer for one request: a result with the reasons. */
  private class Answer extends StewardOutcome.Result {
    public List<DisputeReason> reasons;
  }

  /**
   * The dispute reasons, for each request.
   * @param inputs one per request
   * @return one output per request, in order
   */
  @InvocableMethod(
    label='Get Dispute Reasons'
    description='ST-06. The reasons a statement can be disputed for and the evidence each one needs. Use to match the customer\'s complaint to a reason before opening a dispute, and to tell them what to send.'
    category='Steward Service Agent'
  )
  public static List<Output> run(List<Input> inputs) {
    AgentActions.Calls calls = new AgentActions.Calls(
      ACTION,
      sessionIdsOf(inputs)
    );
    for (Integer i = 0; i < calls.count(); i++) {
      calls.begin(i, new Answer(), 'Dispute reasons');
    }
    try {
      AgentActions.failIfSimulated();
      List<DisputeReason> catalog = toReasons(
        DisputeEvidenceCatalog.getReasons()
      );
      for (Integer i = 0; i < calls.count(); i++) {
        calls.serve(i, completed(catalog));
      }
    } catch (Exception error) {
      calls.fail(error);
    }

    List<Output> outputs = new List<Output>();
    for (StewardOutcome.Result result : calls.finish()) {
      Answer answer = (Answer) result;
      Output output = new Output();
      output.outcome = answer.outcome;
      output.reasonCode = answer.reasonCode;
      output.reference = answer.reference;
      output.reasons = answer.reasons;
      outputs.add(output);
    }
    return outputs;
  }

  private static Answer completed(List<DisputeReason> reasons) {
    Answer answer = new Answer();
    answer.reasons = reasons;
    answer.setOutcome(StewardOutcome.COMPLETED, null);
    return answer;
  }

  private static List<DisputeReason> toReasons(
    List<DisputeEvidenceCatalog.ReasonOption> options
  ) {
    List<DisputeReason> reasons = new List<DisputeReason>();
    for (DisputeEvidenceCatalog.ReasonOption option : options) {
      DisputeReason reason = new DisputeReason();
      reason.value = option.value;
      reason.label = option.label;
      reason.evidence = AgentActions.evidenceLines(option.evidence);
      reasons.add(reason);
    }
    return reasons;
  }

  private static List<String> sessionIdsOf(List<Input> inputs) {
    List<String> sessionIds = new List<String>();
    for (Input input : inputs) {
      sessionIds.add(input?.sessionId);
    }
    return sessionIds;
  }
}
