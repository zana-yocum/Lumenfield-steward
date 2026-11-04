/**
 * S-01, ST-05, ST-12. Runs the payment link the way the agent will: as a user on the Einstein Agent
 * User profile with only PS_Steward_Agent and what the Steward Agent group is given
 * (AgentTestUsers). That access is enough to read the customer's balance and ask Stripe for a
 * link, and the agent still can't get a link for anyone else's statement.
 *
 * Separate from AgentAccessTest because Salesforce refuses a callout after a save in the same
 * test, so the agent user, the customers and the sharing are all made in the setup. Each household
 * has a $120 statement past due since last month.
 */
@IsTest
private class AgentPaymentAccessTest {
  @TestSetup
  static void createData() {
    PortalTestData.giveRunningUserARole();
    List<StewardTestData.Household> households = StewardTestData.createHouseholdsOwing(
      2,
      120.00
    );
    PortalTestData.createCustomers(households);
    AgentTestUsers.createAgentUser(households);
  }

  private static Billing_Statement__c statementOf(Id householdId) {
    return [
      SELECT Id, Name
      FROM Billing_Statement__c
      WHERE Account__c = :householdId
      WITH SYSTEM_MODE
      LIMIT 1
    ];
  }

  private static GetPaymentLinkAction.Input input(
    Id sessionId,
    Id statementId
  ) {
    GetPaymentLinkAction.Input input = new GetPaymentLinkAction.Input();
    input.sessionId = sessionId;
    input.statementId = statementId;
    return input;
  }

  @IsTest
  static void theAgentGetsALinkForItsCustomerOnlyWithItsOwnAccess() {
    List<StewardTestData.Household> households = StewardTestData.existingHouseholds();
    Billing_Statement__c theirs = statementOf(households[0].account.Id);
    Billing_Statement__c someoneElses = statementOf(households[1].account.Id);
    User customer = [
      SELECT Id
      FROM User
      WHERE AccountId = :households[0].account.Id AND IsActive = TRUE
      LIMIT 1
    ];
    AgentTestSessions sessions = new AgentTestSessions()
      .chat(1, customer.Id)
      .install();
    User agent = AgentTestUsers.existingAgentUser();
    StripeMock stripe = new StripeMock()
      .answer(
        'POST /v1/checkout/sessions',
        200,
        new StripeMock.Session('cs_test_1', theirs.Id, 12000).json()
      );
    Test.setMock(HttpCalloutMock.class, stripe);

    List<GetPaymentLinkAction.Output> outputs;
    System.runAs(agent) {
      Test.startTest();
      outputs = GetPaymentLinkAction.run(
        new List<GetPaymentLinkAction.Input>{
          input(sessions.id(1), theirs.Id),
          input(sessions.id(1), someoneElses.Id)
        }
      );
      Test.stopTest();
    }

    Assert.areEqual(
      StewardOutcome.COMPLETED,
      outputs[0].outcome,
      'The agent\'s access is enough: ' + JSON.serialize(outputs[0])
    );
    Assert.areEqual(120.00, outputs[0].amount, 'The customer\'s balance');
    Assert.isNotNull(outputs[0].paymentLink, 'With a link');
    Assert.areEqual(
      StewardOutcome.NOT_FOUND,
      outputs[1].reasonCode,
      'Every household is shared to the agent, but only the chat\'s customer is served'
    );
    Assert.areEqual(
      1,
      stripe.requests.size(),
      'Stripe heard about one statement'
    );
  }
}
