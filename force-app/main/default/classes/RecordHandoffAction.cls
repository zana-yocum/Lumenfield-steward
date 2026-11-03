/**
 * ST-07, ST-11, GR-06. Records that the agent is handing a conversation to a person, with the
 * reason code that led there, so a supervisor can see what the agent couldn't do (ST-11) and the
 * person picking it up can see why. The agent calls it just before the transfer. A chat with no
 * logged-in customer behind it is recorded too: a person is exactly who should take it.
 */
public with sharing class RecordHandoffAction {
  private static final String ACTION = 'RecordHandoffAction';
  /** When the customer asked for a person, or no other code applies. */
  public static final String CUSTOMER_ASKED = 'CUSTOMER_ASKED';
  private static final Pattern REASON_CODE = Pattern.compile('[A-Z_]{1,40}');

  /** One handoff. */
  public class Input {
    @InvocableVariable(
      label='Messaging Session ID'
      description='Bind to $Context.RoutableId. Never let the model fill this.'
      required=true
    )
    public String sessionId;
    @InvocableVariable(
      label='Reason Code'
      description='The reason code from the action that led here, such as ACCOUNT_STATUS or BROKEN_PROMISE_LIMIT, or CUSTOMER_ASKED'
    )
    public String reasonCode;
    @InvocableVariable(
      label='Summary'
      description='One or two sentences for the person taking over: what the customer wants and what was already tried. No card numbers.'
    )
    public String summary;
  }

  /** The handoff as recorded. */
  public class Output {
    @InvocableVariable(label='Outcome' description='HANDOFF')
    public String outcome;
    @InvocableVariable(label='Reason Code')
    public String reasonCode;
    @InvocableVariable(
      label='Reference'
      description='The log number, for the person taking over'
    )
    public String reference;
  }

  /**
   * Records each handoff.
   * @param inputs one per handoff
   * @return one output per handoff, in order
   */
  @InvocableMethod(
    label='Record Handoff'
    description='ST-07. Records why the conversation is going to a person. Call it right before transferring, every time, with the reason code from the action that led here.'
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

    List<StewardOutcome.Result> results = new List<StewardOutcome.Result>();
    List<AgentActionLogger.Entry> entries = new List<AgentActionLogger.Entry>();
    for (Integer i = 0; i < inputs.size(); i++) {
      StewardOutcome.Result result = new StewardOutcome.Result();
      result.setOutcome(
        StewardOutcome.HANDOFF,
        reasonCodeFrom(inputs[i]?.reasonCode)
      );
      results.add(result);
      entries.add(
        AgentActions.entry(
          identities.get(sessionIds[i]),
          ACTION,
          result,
          String.isBlank(inputs[i]?.summary) ? 'Handoff' : inputs[i].summary
        )
      );
    }
    List<Database.SaveResult> saved = AgentActionLogger.log(entries);
    Set<Id> logIds = new Set<Id>();
    for (Database.SaveResult save : saved) {
      if (save.isSuccess()) {
        logIds.add(save.getId());
      }
    }
    Map<Id, String> references = AgentActionLogger.referencesFor(logIds);

    List<Output> outputs = new List<Output>();
    for (Integer i = 0; i < results.size(); i++) {
      Output output = new Output();
      output.outcome = results[i].outcome;
      output.reasonCode = results[i].reasonCode;
      if (i < saved.size() && saved[i].isSuccess()) {
        output.reference = references.get(saved[i].getId());
      }
      outputs.add(output);
    }
    return outputs;
  }

  /**
   * A reason code as given, if it looks like one: capital letters and underscores, at most 40.
   * Anything else is recorded as CUSTOMER_ASKED rather than as free text from the model.
   * @param given what the agent passed
   * @return the reason code to record
   */
  @TestVisible
  private static String reasonCodeFrom(String given) {
    String trimmed = given?.trim();
    return trimmed != null && REASON_CODE.matcher(trimmed).matches()
      ? trimmed
      : CUSTOMER_ASKED;
  }
}
