/**
 * ST-03, ST-12, GR-01, GR-04, GR-06. The service agent's answer to "why did my bill change?": the
 * statement, the one before it, and the reasons the amounts differ, each with its figures, from
 * StatementExplanationService. When the records can't explain a change, fullyExplained is false
 * and the agent offers a dispute or a person instead of guessing (GR-04). A statement ID the model
 * passes is looked for only in the logged-in household (ST-12).
 */
public with sharing class ExplainStatementAction {
  private static final String ACTION = 'ExplainStatementAction';

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
      description='A statement ID from Get Account Summary. Leave empty for the latest statement.'
    )
    public String statementId;
  }

  /** The explanation, or the reason there isn't one. */
  public class Output {
    @InvocableVariable(
      label='Outcome'
      description='COMPLETED, DECLINED_POLICY or FAILED'
    )
    public String outcome;
    @InvocableVariable(
      label='Reason Code'
      description='On a decline or failure, why: NOT_VERIFIED, SESSION_ENDED, WRONG_CHANNEL, NOT_FOUND, NO_STATEMENTS or UNEXPECTED_ERROR'
    )
    public String reasonCode;
    @InvocableVariable(
      label='Reference'
      description='On a failure only: the number the customer can quote to a person'
    )
    public String reference;
    @InvocableVariable(label='Statement' description='The statement explained')
    public StatementExplanationService.StatementSummary statement;
    @InvocableVariable(
      label='Prior Statement'
      description='The statement before it, if any'
    )
    public StatementExplanationService.StatementSummary priorStatement;
    @InvocableVariable(
      label='Reasons'
      description='Why the amounts differ, each with its figures: ESCALATOR, POSTED_CREDIT, UNPAID_PRIOR_STATEMENT, NO_CHANGE, FIRST_STATEMENT or UNEXPLAINED_CHANGE'
    )
    public List<StatementExplanationService.Reason> reasons;
    @InvocableVariable(
      label='Fully Explained'
      description='False when any reason is UNEXPLAINED_CHANGE: offer a dispute or a person, never a guess'
    )
    public Boolean fullyExplained;
  }

  /**
   * The explanation for each request's statement.
   * @param inputs one per request
   * @return one output per request, in order
   */
  @InvocableMethod(
    label='Explain Statement'
    description='ST-03. Why a statement\'s amount is what it is, compared with the one before: the annual escalator, posted credits, unpaid earlier statements. Use when the customer asks why their bill went up or changed.'
    category='Steward Service Agent'
  )
  public static List<Output> run(List<Input> inputs) {
    AgentActions.Calls calls = new AgentActions.Calls(
      ACTION,
      sessionIdsOf(inputs)
    );
    List<StatementExplanationService.Request> requests = new List<StatementExplanationService.Request>();
    List<Integer> sent = new List<Integer>();
    for (Integer i = 0; i < inputs.size(); i++) {
      String statementId = inputs[i]?.statementId;
      String asked =
        'Explain statement ' +
        (String.isBlank(statementId) ? '(latest)' : statementId);
      if (
        calls.begin(i, new StatementExplanationService.Explanation(), asked) &&
        calls.acceptsId(i, statementId)
      ) {
        requests.add(
          new StatementExplanationService.Request(
            calls.household(i),
            AgentActions.toId(statementId)
          )
        );
        sent.add(i);
      }
    }
    try {
      AgentActions.failIfSimulated();
      calls.serveAll(sent, StatementExplanationService.explain(requests));
    } catch (Exception error) {
      calls.fail(error);
    }

    List<Output> outputs = new List<Output>();
    for (StewardOutcome.Result result : calls.finish()) {
      outputs.add(toOutput((StatementExplanationService.Explanation) result));
    }
    return outputs;
  }

  private static Output toOutput(
    StatementExplanationService.Explanation explanation
  ) {
    Output output = new Output();
    output.outcome = explanation.outcome;
    output.reasonCode = explanation.reasonCode;
    output.reference = explanation.reference;
    if (explanation.outcome == StewardOutcome.COMPLETED) {
      output.statement = explanation.statement;
      output.priorStatement = explanation.priorStatement;
      output.reasons = explanation.reasons;
      output.fullyExplained = explanation.fullyExplained;
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
