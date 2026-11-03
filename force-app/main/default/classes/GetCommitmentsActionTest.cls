/**
 * ST-02, ST-12, S-08, GR-06. Proves the agent reads only the logged-in customer's own commitments,
 * that a household with none is told so rather than failing, and that a chat with no customer
 * behind it gets nothing.
 */
@IsTest
private class GetCommitmentsActionTest {
  @TestSetup
  static void createData() {
    PortalTestData.giveRunningUserARole();
    List<StewardTestData.Household> households = StewardTestData.createHouseholds(
      2,
      StewardTestData.ACCOUNT_CURRENT
    );
    Opportunity deal = StewardTestData.deal(households[0]);
    insert deal;
    insert StewardTestData.commitment(
      deal,
      'Payment Coverage',
      240.00,
      2,
      'Lumenfield covers the first two monthly payments.',
      'Recorded'
    );
  }

  @IsTest
  static void eachCustomerGetsOnlyTheirOwnCommitments() {
    List<User> customers = PortalTestData.createCustomers(
      StewardTestData.existingHouseholds()
    );
    AgentTestSessions sessions = new AgentTestSessions()
      .chat(1, customers[0].Id)
      .chat(2, customers[1].Id)
      .install();

    Test.startTest();
    List<GetCommitmentsAction.Output> outputs = GetCommitmentsAction.run(
      new List<GetCommitmentsAction.Input>{
        input(sessions.id(1)),
        input(sessions.id(2))
      }
    );
    Test.stopTest();

    GetCommitmentsAction.Output promised = outputs[0];
    Assert.areEqual(
      StewardOutcome.COMPLETED,
      promised.outcome,
      'Completed: ' + promised.reasonCode
    );
    Assert.areEqual(1, promised.commitments.size(), 'One commitment');
    Assert.areEqual(
      'Payment Coverage',
      promised.commitments[0].commitmentType,
      'Its type'
    );
    Assert.areEqual(240.00, promised.commitments[0].value, 'Its value');
    Assert.areEqual(2, promised.commitments[0].monthsCovered, 'Months covered');

    GetCommitmentsAction.Output none = outputs[1];
    Assert.areEqual(
      StewardOutcome.COMPLETED,
      none.outcome,
      'A household with none still completes'
    );
    Assert.areEqual(
      CommitmentReadService.NONE_RECORDED,
      none.reasonCode,
      'And says nothing was recorded'
    );
    Assert.areEqual(
      0,
      none.commitments.size(),
      'The second customer doesn\'t see the first one\'s commitment'
    );
    Assert.areEqual(
      2,
      [SELECT COUNT() FROM Agent_Action_Log__c WITH SYSTEM_MODE],
      'One log record per request'
    );
  }

  @IsTest
  static void aChatWithNoCustomerBehindItGetsNothing() {
    AgentSession.SessionFacts ended = AgentTestSessions.webChat(1, null);
    ended.status = 'Ended';
    AgentTestSessions sessions = new AgentTestSessions().add(ended).install();

    GetCommitmentsAction.Output output = GetCommitmentsAction.run(
      new List<GetCommitmentsAction.Input>{ input(sessions.id(1)) }
    )[0];

    Assert.areEqual(StewardOutcome.DECLINED_POLICY, output.outcome, 'Declined');
    Assert.areEqual(AgentSession.SESSION_ENDED, output.reasonCode, 'Reason');
    Assert.isNull(output.commitments, 'Nothing read');
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

    GetCommitmentsAction.Output output = GetCommitmentsAction.run(
      new List<GetCommitmentsAction.Input>{ input(sessions.id(1)) }
    )[0];

    Assert.areEqual(StewardOutcome.FAILED, output.outcome, 'Failed');
    Assert.areEqual(AgentActions.UNEXPECTED_ERROR, output.reasonCode, 'Reason');
    Assert.isNotNull(output.reference, 'A number to quote');
    Assert.isNull(output.commitments, 'Nothing on a failure');
  }

  private static GetCommitmentsAction.Input input(Id sessionId) {
    GetCommitmentsAction.Input input = new GetCommitmentsAction.Input();
    input.sessionId = sessionId;
    return input;
  }
}
