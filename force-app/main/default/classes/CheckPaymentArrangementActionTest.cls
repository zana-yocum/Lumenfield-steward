/**
 * ST-04, ST-12, GR-03, GR-06. Proves the agent's arrangement check answers for the logged-in
 * customer's household with the policy's own figures, saves nothing, and gives a chat with no
 * customer behind it nothing. Policy values are read from Accord's records, never assumed.
 *
 * The household owes $120, past due since the start of last month.
 */
@IsTest
private class CheckPaymentArrangementActionTest {
  @TestSetup
  static void createData() {
    PortalTestData.giveRunningUserARole();
    List<StewardTestData.Household> households = StewardTestData.createHouseholds(
      1,
      StewardTestData.ACCOUNT_DELINQUENT
    );
    insert StewardTestData.statement(
      households[0],
      StewardTestData.monthStart(1),
      120.00,
      StewardTestData.STATEMENT_PAST_DUE
    );
  }

  @IsTest
  static void anArrangementInsidePolicyIsEligibleAndNothingIsSaved() {
    List<User> customers = PortalTestData.createCustomers(
      StewardTestData.existingHouseholds()
    );
    AgentTestSessions sessions = new AgentTestSessions()
      .chat(1, customers[0].Id)
      .install();
    Date nextWeek = Date.today().addDays(7);

    Test.startTest();
    CheckPaymentArrangementAction.Output output = CheckPaymentArrangementAction.run(
      new List<CheckPaymentArrangementAction.Input>{
        input(sessions.id(1), nextWeek, 120.00)
      }
    )[0];
    Test.stopTest();

    Assert.areEqual(
      StewardOutcome.COMPLETED,
      output.outcome,
      'Completed: ' + output.reasonCode
    );
    Assert.areEqual(
      PaymentArrangementService.ELIGIBLE,
      output.reasonCode,
      'Eligible'
    );
    Assert.areEqual(nextWeek, output.promiseDate, 'The date asked about');
    Assert.areEqual(120.00, output.promiseAmount, 'The amount asked about');
    Assert.areEqual(
      0,
      [SELECT COUNT() FROM Promise_to_Pay__c WITH SYSTEM_MODE],
      'A check saves nothing'
    );
    Agent_Action_Log__c log = [
      SELECT Action__c, Outcome__c, Details__c
      FROM Agent_Action_Log__c
      WITH SYSTEM_MODE
    ];
    Assert.areEqual('CheckPaymentArrangementAction', log.Action__c, 'Action');
    Assert.areEqual('Completed', log.Outcome__c, 'Outcome');
    Assert.isTrue(
      log.Details__c.contains('120'),
      'What was asked is in the log: ' + log.Details__c
    );
  }

  @IsTest
  static void aDateOutsideTheWindowSaysHowFarIsAllowed() {
    List<User> customers = PortalTestData.createCustomers(
      StewardTestData.existingHouseholds()
    );
    AgentTestSessions sessions = new AgentTestSessions()
      .chat(1, customers[0].Id)
      .install();
    Integer windowDays = StewardTestData.policyNumber('Promise_Window_Days')
      .intValue();

    CheckPaymentArrangementAction.Output output = CheckPaymentArrangementAction.run(
      new List<CheckPaymentArrangementAction.Input>{
        input(sessions.id(1), Date.today().addDays(windowDays + 1), 120.00)
      }
    )[0];

    Assert.areEqual(StewardOutcome.DECLINED_POLICY, output.outcome, 'Declined');
    Assert.areEqual(
      PaymentArrangementService.DATE_OUTSIDE_WINDOW,
      output.reasonCode,
      'Reason'
    );
    Assert.areEqual(
      Date.today().addDays(windowDays),
      output.latestAllowedDate,
      'The latest date the policy allows, from Accord\'s policy record'
    );
  }

  @IsTest
  static void aChatWithNoCustomerBehindItGetsNothing() {
    AgentTestSessions sessions = new AgentTestSessions()
      .chat(1, null)
      .install();

    CheckPaymentArrangementAction.Output output = CheckPaymentArrangementAction.run(
      new List<CheckPaymentArrangementAction.Input>{
        input(sessions.id(1), Date.today().addDays(7), 120.00)
      }
    )[0];

    Assert.areEqual(StewardOutcome.DECLINED_POLICY, output.outcome, 'Declined');
    Assert.areEqual(AgentSession.NOT_VERIFIED, output.reasonCode, 'Reason');
    Assert.isNull(output.pastDueBalance, 'No figures without a household');
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

    CheckPaymentArrangementAction.Output output = CheckPaymentArrangementAction.run(
      new List<CheckPaymentArrangementAction.Input>{
        input(sessions.id(1), Date.today().addDays(7), 120.00)
      }
    )[0];

    Assert.areEqual(StewardOutcome.FAILED, output.outcome, 'Failed');
    Assert.isNotNull(output.reference, 'A number to quote');
  }

  private static CheckPaymentArrangementAction.Input input(
    Id sessionId,
    Date promiseDate,
    Decimal amount
  ) {
    CheckPaymentArrangementAction.Input input = new CheckPaymentArrangementAction.Input();
    input.sessionId = sessionId;
    input.promiseDate = promiseDate;
    input.amount = amount;
    return input;
  }
}
