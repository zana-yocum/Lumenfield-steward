/**
 * ST-01, ST-12, GR-01, GR-04, GR-06. The service agent's answer to "what do I owe?": the logged-in
 * customer's balances, statements newest first with their payments, and any open promise to pay,
 * from AccountSnapshotService. The household comes from the chat's session (AgentSession), never
 * from the conversation, and every request is logged.
 */
public with sharing class GetAccountSummaryAction {
  private static final String ACTION = 'GetAccountSummaryAction';

  /** One request. */
  public class Input {
    @InvocableVariable(
      label='Messaging Session ID'
      description='Bind to $Context.RoutableId. Never let the model fill this.'
      required=true
    )
    public String sessionId;
  }

  /** The household's position, or the reason there isn't one. */
  public class Output {
    @InvocableVariable(
      label='Outcome'
      description='COMPLETED, DECLINED_POLICY or FAILED'
    )
    public String outcome;
    @InvocableVariable(
      label='Reason Code'
      description='Why it was declined or failed: NOT_VERIFIED, SESSION_ENDED, WRONG_CHANNEL, NOT_FOUND or UNEXPECTED_ERROR'
    )
    public String reasonCode;
    @InvocableVariable(
      label='Reference'
      description='On a failure only: the number the customer can quote to a person'
    )
    public String reference;
    @InvocableVariable(
      label='Current Balance'
      description='What is owed across all statements'
    )
    public Decimal currentBalance;
    @InvocableVariable(
      label='Past Due Balance'
      description='What is owed on statements past their due date'
    )
    public Decimal pastDueBalance;
    @InvocableVariable(
      label='Oldest Past Due Date'
      description='The due date of the oldest past-due statement'
    )
    public Date oldestPastDueDate;
    @InvocableVariable(
      label='Next Due Date'
      description='The earliest due date among statements not yet due that still have a balance'
    )
    public Date nextDueDate;
    @InvocableVariable(
      label='Next Due Amount'
      description='That statement\'s balance'
    )
    public Decimal nextDueAmount;
    @InvocableVariable(
      label='Statements'
      description='Newest first, each with its payments (date and amount only) and any open dispute'
    )
    public List<AccountSnapshotService.StatementLine> statements;
    @InvocableVariable(
      label='Open Promise to Pay'
      description='The Active or Pending Approval promise to pay, if there is one'
    )
    public AccountSnapshotService.PromiseLine openPromise;
  }

  /**
   * The summary for each request's household.
   * @param inputs one per request
   * @return one output per request, in order
   */
  @InvocableMethod(
    label='Get Account Summary'
    description='ST-01. The logged-in customer\'s balances, statements, payments and open promise to pay. Use for questions about what they owe, when it\'s due, or whether a payment arrived.'
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

    List<AccountSnapshotService.Snapshot> results = new List<AccountSnapshotService.Snapshot>();
    List<AgentActionLogger.Entry> entries = new List<AgentActionLogger.Entry>();
    Map<Id, AccountSnapshotService.Snapshot> snapshots;
    String failure;
    try {
      AgentActions.failIfSimulated();
      snapshots = AccountSnapshotService.getSnapshots(households);
    } catch (Exception error) {
      failure = AgentActions.describe(error);
    }
    for (String sessionId : sessionIds) {
      AgentSession.Identity identity = identities.get(sessionId);
      AccountSnapshotService.Snapshot result;
      String details = 'Account summary';
      if (!identity.isVerified()) {
        result = new AccountSnapshotService.Snapshot();
        AgentActions.declineUnverified(result, identity);
      } else if (failure != null) {
        result = new AccountSnapshotService.Snapshot();
        AgentActions.markFailed(result);
        details = failure;
      } else {
        result = snapshots.get(identity.accountId);
      }
      results.add(result);
      entries.add(AgentActions.entry(identity, ACTION, result, details));
    }
    AgentActions.log(entries, results);

    List<Output> outputs = new List<Output>();
    for (AccountSnapshotService.Snapshot result : results) {
      outputs.add(toOutput(result));
    }
    return outputs;
  }

  private static Output toOutput(AccountSnapshotService.Snapshot snapshot) {
    Output output = new Output();
    output.outcome = snapshot.outcome;
    output.reasonCode = snapshot.reasonCode;
    output.reference = snapshot.reference;
    if (snapshot.outcome == StewardOutcome.COMPLETED) {
      output.currentBalance = snapshot.currentBalance;
      output.pastDueBalance = snapshot.pastDueBalance;
      output.oldestPastDueDate = snapshot.oldestPastDueDate;
      output.nextDueDate = snapshot.nextDueDate;
      output.nextDueAmount = snapshot.nextDueAmount;
      output.statements = snapshot.statements;
      output.openPromise = snapshot.openPromise;
    }
    return output;
  }
}
