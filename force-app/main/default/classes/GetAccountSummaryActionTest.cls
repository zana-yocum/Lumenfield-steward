/**
 * ST-01, ST-12, GR-01, GR-04, GR-06. Proves the agent's account summary is the logged-in
 * customer's own, to the cent, that a chat with no customer behind it gets nothing, and that
 * every request leaves one log record naming the conversation.
 *
 * The known-answer household (StewardTestData.addKnownAnswerHistory): current balance $310,
 * past due $190.
 */
@IsTest
private class GetAccountSummaryActionTest {
  @TestSetup
  static void createData() {
    PortalTestData.giveRunningUserARole();
    List<StewardTestData.Household> households = StewardTestData.createHouseholds(
      2,
      StewardTestData.ACCOUNT_DELINQUENT
    );
    StewardTestData.addKnownAnswerHistory(households[0]);
  }

  @IsTest
  static void aCustomerGetsTheirOwnBalancesToTheCent() {
    List<StewardTestData.Household> households = StewardTestData.existingHouseholds();
    List<User> customers = PortalTestData.createCustomers(households);
    AgentTestSessions sessions = new AgentTestSessions()
      .chat(1, customers[0].Id)
      .chat(2, customers[1].Id)
      .install();

    Test.startTest();
    List<GetAccountSummaryAction.Output> outputs = GetAccountSummaryAction.run(
      new List<GetAccountSummaryAction.Input>{
        input(sessions.id(1)),
        input(sessions.id(2))
      }
    );
    Test.stopTest();

    GetAccountSummaryAction.Output known = outputs[0];
    Assert.areEqual(
      StewardOutcome.COMPLETED,
      known.outcome,
      'Completed: ' + known.reasonCode
    );
    Assert.areEqual(310.00, known.currentBalance, 'Current balance');
    Assert.areEqual(190.00, known.pastDueBalance, 'Past-due balance');
    Assert.areEqual(4, known.statements.size(), 'All four statements');
    Assert.areEqual(
      0.00,
      outputs[1].currentBalance,
      'The second chat gets the second household, which owes nothing'
    );
    Assert.areEqual(0, outputs[1].statements.size(), 'And has no statements');

    List<Agent_Action_Log__c> logs = [
      SELECT Account__c, Action__c, Outcome__c, Conversation_Id__c
      FROM Agent_Action_Log__c
      WITH SYSTEM_MODE
      ORDER BY Name
    ];
    Assert.areEqual(2, logs.size(), 'One log record per request');
    Assert.areEqual(households[0].account.Id, logs[0].Account__c, 'Household');
    Assert.areEqual('GetAccountSummaryAction', logs[0].Action__c, 'Action');
    Assert.areEqual('Completed', logs[0].Outcome__c, 'Outcome');
    Assert.areEqual(
      String.valueOf(sessions.id(1)),
      logs[0].Conversation_Id__c,
      'The conversation is the messaging session'
    );
  }

  @IsTest
  static void aChatWithNoCustomerBehindItGetsNothing() {
    AgentTestSessions sessions = new AgentTestSessions()
      .chat(1, null)
      .install();

    GetAccountSummaryAction.Output output = GetAccountSummaryAction.run(
      new List<GetAccountSummaryAction.Input>{ input(sessions.id(1)) }
    )[0];

    Assert.areEqual(StewardOutcome.DECLINED_POLICY, output.outcome, 'Declined');
    Assert.areEqual(AgentSession.NOT_VERIFIED, output.reasonCode, 'Reason');
    Assert.isNull(output.currentBalance, 'No figures');
    Assert.isNull(output.statements, 'No statements');
    Agent_Action_Log__c log = [
      SELECT Account__c, Outcome__c, Reason_Code__c
      FROM Agent_Action_Log__c
      WITH SYSTEM_MODE
    ];
    Assert.isNull(log.Account__c, 'No household on the log');
    Assert.areEqual('Declined by Policy', log.Outcome__c, 'Logged as declined');
    Assert.areEqual(AgentSession.NOT_VERIFIED, log.Reason_Code__c, 'Reason');
  }

  @IsTest
  static void aFailureGivesAReferenceNotTheError() {
    List<StewardTestData.Household> households = StewardTestData.existingHouseholds();
    List<User> customers = PortalTestData.createCustomers(households);
    AgentTestSessions sessions = new AgentTestSessions()
      .chat(1, customers[0].Id)
      .install();
    AgentActions.simulatedFailure = new DmlException('Simulated failure');

    GetAccountSummaryAction.Output output = GetAccountSummaryAction.run(
      new List<GetAccountSummaryAction.Input>{ input(sessions.id(1)) }
    )[0];

    Assert.areEqual(StewardOutcome.FAILED, output.outcome, 'Failed');
    Assert.areEqual(AgentActions.UNEXPECTED_ERROR, output.reasonCode, 'Reason');
    Agent_Action_Log__c log = [
      SELECT Name, Details__c
      FROM Agent_Action_Log__c
      WITH SYSTEM_MODE
    ];
    Assert.areEqual(log.Name, output.reference, 'The log number to quote');
    Assert.isTrue(
      log.Details__c.contains('Simulated failure'),
      'The error is in the log: ' + log.Details__c
    );
    Assert.isNull(output.currentBalance, 'No figures on a failure');
  }

  private static GetAccountSummaryAction.Input input(Id sessionId) {
    GetAccountSummaryAction.Input input = new GetAccountSummaryAction.Input();
    input.sessionId = sessionId;
    return input;
  }
}
