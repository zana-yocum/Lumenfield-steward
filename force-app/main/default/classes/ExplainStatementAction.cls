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
    List<String> sessionIds = new List<String>();
    for (Input input : inputs) {
      sessionIds.add(input?.sessionId);
    }
    Map<String, AgentSession.Identity> identities = AgentActions.identities(
      sessionIds
    );

    // First pass: answer what needs no reading, and queue the rest for one service call.
    List<StatementExplanationService.Explanation> results = new List<StatementExplanationService.Explanation>();
    List<StatementExplanationService.Request> requests = new List<StatementExplanationService.Request>();
    List<Integer> queued = new List<Integer>();
    for (Integer i = 0; i < inputs.size(); i++) {
      AgentSession.Identity identity = identities.get(sessionIds[i]);
      String statementId = inputs[i]?.statementId;
      StatementExplanationService.Explanation result = new StatementExplanationService.Explanation();
      if (!identity.isVerified()) {
        AgentActions.declineUnverified(result, identity);
      } else if (
        String.isNotBlank(statementId) && AgentActions.toId(statementId) == null
      ) {
        AgentActions.declineNotFound(result);
      } else {
        requests.add(
          new StatementExplanationService.Request(
            identity.accountId,
            AgentActions.toId(statementId)
          )
        );
        queued.add(i);
      }
      results.add(result);
    }

    String failure;
    try {
      AgentActions.failIfSimulated();
      List<StatementExplanationService.Explanation> explained = StatementExplanationService.explain(
        requests
      );
      for (Integer q = 0; q < queued.size(); q++) {
        results[queued[q]] = explained[q];
      }
    } catch (Exception error) {
      failure = AgentActions.describe(error);
      for (Integer i : queued) {
        AgentActions.markFailed(results[i]);
      }
    }

    List<AgentActionLogger.Entry> entries = new List<AgentActionLogger.Entry>();
    for (Integer i = 0; i < inputs.size(); i++) {
      String statementId = inputs[i]?.statementId;
      String details = results[i].outcome == StewardOutcome.FAILED
        ? failure
        : 'Explain statement ' +
          (String.isBlank(statementId) ? '(latest)' : statementId);
      entries.add(
        AgentActions.entry(
          identities.get(sessionIds[i]),
          ACTION,
          results[i],
          details
        )
      );
    }
    AgentActions.log(entries, results);

    List<Output> outputs = new List<Output>();
    for (StatementExplanationService.Explanation result : results) {
      Output output = new Output();
      output.outcome = result.outcome;
      output.reasonCode = result.reasonCode;
      output.reference = result.reference;
      if (result.outcome == StewardOutcome.COMPLETED) {
        output.statement = result.statement;
        output.priorStatement = result.priorStatement;
        output.reasons = result.reasons;
        output.fullyExplained = result.fullyExplained;
      }
      outputs.add(output);
    }
    return outputs;
  }
}
