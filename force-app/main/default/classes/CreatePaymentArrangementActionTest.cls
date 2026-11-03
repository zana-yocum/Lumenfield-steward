/**
 * ST-04, ST-12, GR-02, GR-03, GR-05, GR-06. Proves a confirmed arrangement inside policy saves as
 * an Active promise on the logged-in customer's household, with Accord's hold date; that one
 * outside policy saves nothing; and that a chat with no customer behind it can't create anything.
 *
 * The household owes $120, past due since the start of last month.
 */
@IsTest
private class CreatePaymentArrangementActionTest {
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
  static void aConfirmedArrangementSavesAsAnActivePromise() {
    List<StewardTestData.Household> households = StewardTestData.existingHouseholds();
    List<User> customers = PortalTestData.createCustomers(households);
    AgentTestSessions sessions = new AgentTestSessions()
      .chat(1, customers[0].Id)
      .install();
    Date nextWeek = Date.today().addDays(7);
    Integer graceDays = StewardTestData.policyNumber('Promise_Grace_Days')
      .intValue();

    Test.startTest();
    CreatePaymentArrangementAction.Output output = CreatePaymentArrangementAction.run(
      new List<CreatePaymentArrangementAction.Input>{
        input(sessions.id(1), nextWeek, 120.00)
      }
    )[0];
    Test.stopTest();

    Assert.areEqual(
      StewardOutcome.COMPLETED,
      output.outcome,
      'Completed: ' + output.reasonCode
    );
    Assert.areEqual('Active', output.promiseStatus, 'Saved as Active');
    Assert.isNotNull(output.promiseNumber, 'With its number to quote');
    Assert.areEqual(
      nextWeek.addDays(graceDays),
      output.holdUntil,
      'Held until the grace date Accord set'
    );
    Promise_to_Pay__c saved = [
      SELECT Account__c, Promise_Amount__c, Promise_Date__c, Status__c
      FROM Promise_to_Pay__c
      WITH SYSTEM_MODE
    ];
    Assert.areEqual(
      households[0].account.Id,
      saved.Account__c,
      'On the logged-in customer\'s household'
    );
    Assert.areEqual(120.00, saved.Promise_Amount__c, 'The confirmed amount');
    Assert.areEqual(nextWeek, saved.Promise_Date__c, 'The confirmed date');
  }

  @IsTest
  static void lessThanTheMinimumSavesNothing() {
    List<User> customers = PortalTestData.createCustomers(
      StewardTestData.existingHouseholds()
    );
    AgentTestSessions sessions = new AgentTestSessions()
      .chat(1, customers[0].Id)
      .install();

    CreatePaymentArrangementAction.Output output = CreatePaymentArrangementAction.run(
      new List<CreatePaymentArrangementAction.Input>{
        input(sessions.id(1), Date.today().addDays(7), 20.00)
      }
    )[0];

    Assert.areEqual(StewardOutcome.DECLINED_POLICY, output.outcome, 'Declined');
    Assert.areEqual(
      PaymentArrangementService.AMOUNT_BELOW_MINIMUM,
      output.reasonCode,
      'Reason'
    );
    Assert.isNotNull(output.minimumAmount, 'With the least that\'s allowed');
    Assert.areEqual(
      0,
      [SELECT COUNT() FROM Promise_to_Pay__c WITH SYSTEM_MODE],
      'Nothing saved'
    );
  }

  @IsTest
  static void aChatWithNoCustomerBehindItCreatesNothing() {
    AgentTestSessions sessions = new AgentTestSessions()
      .chat(1, null)
      .install();

    CreatePaymentArrangementAction.Output output = CreatePaymentArrangementAction.run(
      new List<CreatePaymentArrangementAction.Input>{
        input(sessions.id(1), Date.today().addDays(7), 120.00)
      }
    )[0];

    Assert.areEqual(StewardOutcome.DECLINED_POLICY, output.outcome, 'Declined');
    Assert.areEqual(AgentSession.NOT_VERIFIED, output.reasonCode, 'Reason');
    Assert.areEqual(
      0,
      [SELECT COUNT() FROM Promise_to_Pay__c WITH SYSTEM_MODE],
      'Nothing saved'
    );
  }

  @IsTest
  static void aFailureSavesNothingAndGivesAReference() {
    List<User> customers = PortalTestData.createCustomers(
      StewardTestData.existingHouseholds()
    );
    AgentTestSessions sessions = new AgentTestSessions()
      .chat(1, customers[0].Id)
      .install();
    AgentActions.simulatedFailure = new DmlException('Simulated failure');

    CreatePaymentArrangementAction.Output output = CreatePaymentArrangementAction.run(
      new List<CreatePaymentArrangementAction.Input>{
        input(sessions.id(1), Date.today().addDays(7), 120.00)
      }
    )[0];

    Assert.areEqual(StewardOutcome.FAILED, output.outcome, 'Failed');
    Assert.isNotNull(output.reference, 'A number to quote');
    Assert.isNull(output.promiseNumber, 'No promise');
    Assert.areEqual(
      0,
      [SELECT COUNT() FROM Promise_to_Pay__c WITH SYSTEM_MODE],
      'Nothing saved'
    );
  }

  private static CreatePaymentArrangementAction.Input input(
    Id sessionId,
    Date promiseDate,
    Decimal amount
  ) {
    CreatePaymentArrangementAction.Input input = new CreatePaymentArrangementAction.Input();
    input.sessionId = sessionId;
    input.promiseDate = promiseDate;
    input.amount = amount;
    return input;
  }
}
