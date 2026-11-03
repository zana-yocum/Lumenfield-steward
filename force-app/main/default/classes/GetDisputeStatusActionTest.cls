/**
 * ST-06, ST-12, GR-06. Proves the agent sees the logged-in customer's own billing disputes, never
 * another household's or one of Accord's Default Reviews, and that a chat with no customer behind
 * it sees nothing.
 *
 * Household A has one billing dispute and a Default Review. Household B has none.
 */
@IsTest
private class GetDisputeStatusActionTest {
  private static final String PAYMENT_NOT_POSTED = 'Payment Not Posted';

  @TestSetup
  static void createData() {
    PortalTestData.giveRunningUserARole();
    List<StewardTestData.Household> households = StewardTestData.createHouseholds(
      2,
      StewardTestData.ACCOUNT_DELINQUENT
    );
    Billing_Statement__c statement = StewardTestData.statement(
      households[0],
      StewardTestData.monthStart(2),
      120,
      StewardTestData.STATEMENT_PAST_DUE
    );
    insert statement;
    StewardTestData.insertDispute(households[0], statement, PAYMENT_NOT_POSTED);
    PortalTestData.insertDefaultReview(households[0]);
  }

  @IsTest
  static void eachCustomerSeesOnlyTheirOwnBillingDisputes() {
    List<User> customers = PortalTestData.createCustomers(
      StewardTestData.existingHouseholds()
    );
    AgentTestSessions sessions = new AgentTestSessions()
      .chat(1, customers[0].Id)
      .chat(2, customers[1].Id)
      .install();

    Test.startTest();
    List<GetDisputeStatusAction.Output> outputs = GetDisputeStatusAction.run(
      new List<GetDisputeStatusAction.Input>{
        input(sessions.id(1)),
        input(sessions.id(2))
      }
    );
    Test.stopTest();

    Assert.areEqual(
      StewardOutcome.COMPLETED,
      outputs[0].outcome,
      'Completed: ' + outputs[0].reasonCode
    );
    Assert.areEqual(
      1,
      outputs[0].disputes.size(),
      'The billing dispute, and not the Default Review'
    );
    Assert.areEqual(
      PAYMENT_NOT_POSTED,
      outputs[0].disputes[0].reason,
      'Its reason'
    );
    Assert.areEqual(
      0,
      outputs[1].disputes.size(),
      'The second customer sees none of the first one\'s'
    );
  }

  @IsTest
  static void aChatWithNoCustomerBehindItSeesNothing() {
    AgentTestSessions sessions = new AgentTestSessions()
      .chat(1, null)
      .install();

    GetDisputeStatusAction.Output output = GetDisputeStatusAction.run(
      new List<GetDisputeStatusAction.Input>{ input(sessions.id(1)) }
    )[0];

    Assert.areEqual(StewardOutcome.DECLINED_POLICY, output.outcome, 'Declined');
    Assert.areEqual(AgentSession.NOT_VERIFIED, output.reasonCode, 'Reason');
    Assert.isNull(output.disputes, 'Nothing read');
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

    GetDisputeStatusAction.Output output = GetDisputeStatusAction.run(
      new List<GetDisputeStatusAction.Input>{ input(sessions.id(1)) }
    )[0];

    Assert.areEqual(StewardOutcome.FAILED, output.outcome, 'Failed');
    Assert.isNotNull(output.reference, 'A number to quote');
  }

  private static GetDisputeStatusAction.Input input(Id sessionId) {
    GetDisputeStatusAction.Input input = new GetDisputeStatusAction.Input();
    input.sessionId = sessionId;
    return input;
  }
}
