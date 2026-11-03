/**
 * ST-03, ST-12, GR-04, GR-06. Proves the agent explains the logged-in customer's own statements:
 * the latest by default or one it names, never another household's, and never a guess when the
 * value it was given isn't a statement ID.
 *
 * The known-answer household (StewardTestData.addKnownAnswerHistory): four $120 statements, the
 * latest open and due in two weeks, two earlier ones past due.
 */
@IsTest
private class ExplainStatementActionTest {
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
  static void explainsTheLatestStatementByDefault() {
    List<User> customers = PortalTestData.createCustomers(
      StewardTestData.existingHouseholds()
    );
    AgentTestSessions sessions = new AgentTestSessions()
      .chat(1, customers[0].Id)
      .install();

    Test.startTest();
    ExplainStatementAction.Output output = ExplainStatementAction.run(
      new List<ExplainStatementAction.Input>{ input(sessions.id(1), null) }
    )[0];
    Test.stopTest();

    Assert.areEqual(
      StewardOutcome.COMPLETED,
      output.outcome,
      'Completed: ' + output.reasonCode
    );
    Assert.areEqual(120.00, output.statement.amountDue, 'Amount due');
    Assert.areEqual(
      Date.today().addDays(14),
      output.statement.dueDate,
      'The latest statement is the one due in two weeks'
    );
    Assert.areEqual(
      120.00,
      output.priorStatement.amountDue,
      'Compared with the one before'
    );
    Assert.isFalse(output.reasons.isEmpty(), 'With its reasons');
    Assert.isTrue(output.fullyExplained, 'Nothing the records can\'t explain');
  }

  @IsTest
  static void explainsTheStatementItNames() {
    List<User> customers = PortalTestData.createCustomers(
      StewardTestData.existingHouseholds()
    );
    AgentTestSessions sessions = new AgentTestSessions()
      .chat(1, customers[0].Id)
      .install();
    Billing_Statement__c earlier = statementDue(StewardTestData.monthStart(2));

    ExplainStatementAction.Output output = ExplainStatementAction.run(
      new List<ExplainStatementAction.Input>{
        input(sessions.id(1), earlier.Id)
      }
    )[0];

    Assert.areEqual(
      StewardOutcome.COMPLETED,
      output.outcome,
      'Completed: ' + output.reasonCode
    );
    Assert.areEqual(earlier.Id, output.statement.statementId, 'That statement');
  }

  @IsTest
  static void anotherHouseholdsStatementIsNotFound() {
    List<User> customers = PortalTestData.createCustomers(
      StewardTestData.existingHouseholds()
    );
    AgentTestSessions sessions = new AgentTestSessions()
      .chat(2, customers[1].Id)
      .install();
    Billing_Statement__c someoneElses = statementDue(
      StewardTestData.monthStart(2)
    );

    ExplainStatementAction.Output output = ExplainStatementAction.run(
      new List<ExplainStatementAction.Input>{
        input(sessions.id(2), someoneElses.Id)
      }
    )[0];

    Assert.areEqual(
      StewardOutcome.DECLINED_POLICY,
      output.outcome,
      'A statement ID from another household explains nothing'
    );
    Assert.areEqual(StewardOutcome.NOT_FOUND, output.reasonCode, 'Reason');
    Assert.isNull(output.statement, 'Nothing about it comes back');
  }

  @IsTest
  static void wordsInPlaceOfAnIdAreNotGuessedAt() {
    List<User> customers = PortalTestData.createCustomers(
      StewardTestData.existingHouseholds()
    );
    AgentTestSessions sessions = new AgentTestSessions()
      .chat(1, customers[0].Id)
      .install();

    ExplainStatementAction.Output output = ExplainStatementAction.run(
      new List<ExplainStatementAction.Input>{
        input(sessions.id(1), 'my October bill')
      }
    )[0];

    Assert.areEqual(
      StewardOutcome.NOT_FOUND,
      output.reasonCode,
      'Not the latest statement instead: NOT_FOUND'
    );
    Assert.isNull(output.statement, 'Nothing explained');
  }

  @IsTest
  static void aChatWithNoCustomerBehindItGetsNothing() {
    AgentTestSessions sessions = new AgentTestSessions()
      .add(AgentTestSessions.fakeId(1), 'Active', 'Text', null)
      .install();

    ExplainStatementAction.Output output = ExplainStatementAction.run(
      new List<ExplainStatementAction.Input>{ input(sessions.id(1), null) }
    )[0];

    Assert.areEqual(StewardOutcome.DECLINED_POLICY, output.outcome, 'Declined');
    Assert.areEqual(AgentSession.WRONG_CHANNEL, output.reasonCode, 'Reason');
  }

  @IsTest
  static void aFailureGivesAReferenceNotTheError() {
    List<User> customers = PortalTestData.createCustomers(
      StewardTestData.existingHouseholds()
    );
    AgentTestSessions sessions = new AgentTestSessions()
      .chat(1, customers[0].Id)
      .install();
    AgentActions.simulatedFailure = new QueryException('Simulated failure');

    ExplainStatementAction.Output output = ExplainStatementAction.run(
      new List<ExplainStatementAction.Input>{ input(sessions.id(1), null) }
    )[0];

    Assert.areEqual(StewardOutcome.FAILED, output.outcome, 'Failed');
    Assert.isNotNull(output.reference, 'A number to quote');
    Agent_Action_Log__c log = [
      SELECT Details__c
      FROM Agent_Action_Log__c
      WITH SYSTEM_MODE
    ];
    Assert.isTrue(
      log.Details__c.contains('Simulated failure'),
      'The error is in the log: ' + log.Details__c
    );
  }

  private static Billing_Statement__c statementDue(Date dueDate) {
    return [
      SELECT Id
      FROM Billing_Statement__c
      WHERE Due_Date__c = :dueDate
      WITH SYSTEM_MODE
      LIMIT 1
    ];
  }

  private static ExplainStatementAction.Input input(
    Id sessionId,
    String statementId
  ) {
    ExplainStatementAction.Input input = new ExplainStatementAction.Input();
    input.sessionId = sessionId;
    input.statementId = statementId;
    return input;
  }
}
