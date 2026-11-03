/**
 * ST-06, GR-04, GR-06. Proves the agent gets Accord's eight dispute reasons with their evidence,
 * required items first, and that a chat with no customer behind it gets nothing.
 */
@IsTest
private class GetDisputeReasonsActionTest {
  @TestSetup
  static void createData() {
    PortalTestData.giveRunningUserARole();
    StewardTestData.createHouseholds(1, StewardTestData.ACCOUNT_CURRENT);
  }

  @IsTest
  static void listsEveryReasonWithItsEvidenceRequiredFirst() {
    List<User> customers = PortalTestData.createCustomers(
      StewardTestData.existingHouseholds()
    );
    AgentTestSessions sessions = new AgentTestSessions()
      .chat(1, customers[0].Id)
      .install();

    Test.startTest();
    GetDisputeReasonsAction.Output output = GetDisputeReasonsAction.run(
      new List<GetDisputeReasonsAction.Input>{ input(sessions.id(1)) }
    )[0];
    Test.stopTest();

    Assert.areEqual(
      StewardOutcome.COMPLETED,
      output.outcome,
      'Completed: ' + output.reasonCode
    );
    Assert.areEqual(
      DisputeEvidenceCatalog.getReasons().size(),
      output.reasons.size(),
      'Every active reason'
    );
    for (GetDisputeReasonsAction.DisputeReason reason : output.reasons) {
      Assert.isTrue(
        DisputeEvidenceCatalog.isReason(reason.value),
        'A value Open Dispute accepts: ' + reason.value
      );
      Assert.isFalse(
        reason.evidence.isEmpty(),
        'Evidence listed for ' + reason.value
      );
      Boolean optionalSeen = false;
      for (AgentActions.EvidenceLine line : reason.evidence) {
        if (!line.required) {
          optionalSeen = true;
        }
        Assert.isFalse(
          optionalSeen && line.required,
          'Required items come first for ' + reason.value
        );
      }
    }
  }

  @IsTest
  static void aChatWithNoCustomerBehindItGetsNothing() {
    AgentTestSessions sessions = new AgentTestSessions()
      .chat(1, null)
      .install();

    GetDisputeReasonsAction.Output output = GetDisputeReasonsAction.run(
      new List<GetDisputeReasonsAction.Input>{ input(sessions.id(1)) }
    )[0];

    Assert.areEqual(StewardOutcome.DECLINED_POLICY, output.outcome, 'Declined');
    Assert.isNull(output.reasons, 'Nothing');
    Assert.areEqual(
      1,
      [SELECT COUNT() FROM Agent_Action_Log__c WITH SYSTEM_MODE],
      'The attempt is logged'
    );
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

    GetDisputeReasonsAction.Output output = GetDisputeReasonsAction.run(
      new List<GetDisputeReasonsAction.Input>{ input(sessions.id(1)) }
    )[0];

    Assert.areEqual(StewardOutcome.FAILED, output.outcome, 'Failed');
    Assert.isNotNull(output.reference, 'A number to quote');
  }

  private static GetDisputeReasonsAction.Input input(Id sessionId) {
    GetDisputeReasonsAction.Input input = new GetDisputeReasonsAction.Input();
    input.sessionId = sessionId;
    return input;
  }
}
