/**
 * ST-05, ST-12, GR-01, GR-06. Proves the agent's payment link is for the logged-in customer's own
 * statement, for its balance; that a chat with no customer behind it gets nothing; that another
 * household's statement is NOT_FOUND without Stripe hearing of it; and that Stripe being down
 * gives a reference to quote. Every request is logged.
 *
 * Each household has a $120 statement past due since last month and a customer user. All data is
 * made in the setup, because Salesforce refuses a callout after a save in the same test.
 */
@IsTest
private class GetPaymentLinkActionTest {
  @TestSetup
  static void createData() {
    PortalTestData.giveRunningUserARole();
    List<StewardTestData.Household> households = StewardTestData.createHouseholdsOwing(
      2,
      120.00
    );
    PortalTestData.createCustomers(households);
  }

  private static Id household(Integer i) {
    return StewardTestData.existingHouseholds()[i].account.Id;
  }

  private static Billing_Statement__c statementOf(Integer i) {
    return [
      SELECT Id, Name
      FROM Billing_Statement__c
      WHERE Account__c = :household(i)
      WITH SYSTEM_MODE
      LIMIT 1
    ];
  }

  private static AgentTestSessions chatFor(Integer i) {
    User customer = [
      SELECT Id
      FROM User
      WHERE AccountId = :household(i) AND IsActive = TRUE
      LIMIT 1
    ];
    return new AgentTestSessions().chat(1, customer.Id).install();
  }

  private static GetPaymentLinkAction.Input input(
    Id sessionId,
    String statementId
  ) {
    GetPaymentLinkAction.Input input = new GetPaymentLinkAction.Input();
    input.sessionId = sessionId;
    input.statementId = statementId;
    return input;
  }

  @IsTest
  static void theCustomerGetsALinkForTheirOwnStatementsBalance() {
    Billing_Statement__c theirs = statementOf(0);
    Test.setMock(
      HttpCalloutMock.class,
      new StripeMock()
        .answer(
          'POST /v1/checkout/sessions',
          200,
          new StripeMock.Session('cs_test_1', theirs.Id, 12000).json()
        )
    );
    AgentTestSessions sessions = chatFor(0);

    Test.startTest();
    GetPaymentLinkAction.Output output = GetPaymentLinkAction.run(
      new List<GetPaymentLinkAction.Input>{ input(sessions.id(1), null) }
    )[0];
    Test.stopTest();

    Assert.areEqual(
      StewardOutcome.COMPLETED,
      output.outcome,
      'Completed: ' + output.reasonCode
    );
    Assert.areEqual(
      'https://checkout.stripe.com/c/pay/cs_test_1',
      output.paymentLink,
      'Stripe\'s page, to send as it is'
    );
    Assert.areEqual(120.00, output.amount, 'The balance');
    Assert.areEqual(theirs.Name, output.statementNumber, 'Their statement');
    Agent_Action_Log__c logged = [
      SELECT Outcome__c, Account__c
      FROM Agent_Action_Log__c
      WITH SYSTEM_MODE
      LIMIT 1
    ];
    Assert.areEqual('Completed', logged.Outcome__c, 'Logged');
    Assert.areEqual(household(0), logged.Account__c, 'For their household');
  }

  @IsTest
  static void aChatWithNoCustomerBehindItGetsNothing() {
    StripeMock stripe = new StripeMock();
    Test.setMock(HttpCalloutMock.class, stripe);
    Id statementId = statementOf(0).Id;
    AgentTestSessions sessions = new AgentTestSessions()
      .chat(1, null)
      .install();

    GetPaymentLinkAction.Output output = GetPaymentLinkAction.run(
      new List<GetPaymentLinkAction.Input>{ input(sessions.id(1), statementId) }
    )[0];

    Assert.areEqual(StewardOutcome.DECLINED_POLICY, output.outcome, 'Declined');
    Assert.areEqual(AgentSession.NOT_VERIFIED, output.reasonCode, 'Reason');
    Assert.isNull(output.paymentLink, 'No link');
    Assert.isTrue(stripe.requests.isEmpty(), 'Stripe never hears of it');
  }

  @IsTest
  static void anotherHouseholdsStatementIsNotFound() {
    StripeMock stripe = new StripeMock();
    Test.setMock(HttpCalloutMock.class, stripe);
    AgentTestSessions sessions = chatFor(0);
    Id someoneElses = statementOf(1).Id;

    GetPaymentLinkAction.Output output = GetPaymentLinkAction.run(
      new List<GetPaymentLinkAction.Input>{
        input(sessions.id(1), someoneElses)
      }
    )[0];

    Assert.areEqual(StewardOutcome.NOT_FOUND, output.reasonCode, 'Not found');
    Assert.isNull(output.paymentLink, 'No link');
    Assert.isNull(output.amount, 'Nothing about it comes back');
    Assert.isTrue(stripe.requests.isEmpty(), 'Stripe never hears of it');
  }

  @IsTest
  static void wordsInPlaceOfAStatementIdAreNotGuessedAt() {
    AgentTestSessions sessions = chatFor(0);

    GetPaymentLinkAction.Output output = GetPaymentLinkAction.run(
      new List<GetPaymentLinkAction.Input>{
        input(sessions.id(1), '4242 4242 4242 4242')
      }
    )[0];

    Assert.areEqual(
      StewardOutcome.NOT_FOUND,
      output.reasonCode,
      'Not a statement'
    );
    Agent_Action_Log__c logged = [
      SELECT Details__c
      FROM Agent_Action_Log__c
      WITH SYSTEM_MODE
      LIMIT 1
    ];
    Assert.isFalse(
      logged.Details__c.contains('4242 4242 4242 4242'),
      'A card number never reaches the log: ' + logged.Details__c
    );
  }

  @IsTest
  static void stripeDownGivesAReferenceToQuote() {
    Test.setMock(
      HttpCalloutMock.class,
      new StripeMock()
        .answer(
          'POST /v1/checkout/sessions',
          500,
          StripeMock.error('api_error', null)
        )
    );
    AgentTestSessions sessions = chatFor(0);

    Test.startTest();
    GetPaymentLinkAction.Output output = GetPaymentLinkAction.run(
      new List<GetPaymentLinkAction.Input>{ input(sessions.id(1), null) }
    )[0];
    Test.stopTest();

    Assert.areEqual(StewardOutcome.FAILED, output.outcome, 'Failed');
    Assert.areEqual(
      PaymentCheckoutService.PROVIDER_UNAVAILABLE,
      output.reasonCode,
      'Stripe unavailable'
    );
    Assert.isNotNull(output.reference, 'A number to quote');
    Assert.isNull(output.paymentLink, 'No link');
  }

  @IsTest
  static void anythingUnexpectedFailsWithAReference() {
    AgentTestSessions sessions = chatFor(0);
    AgentActions.simulatedFailure = new QueryException('Simulated failure');

    GetPaymentLinkAction.Output output = GetPaymentLinkAction.run(
      new List<GetPaymentLinkAction.Input>{ input(sessions.id(1), null) }
    )[0];

    Assert.areEqual(StewardOutcome.FAILED, output.outcome, 'Failed');
    Assert.isNotNull(output.reference, 'A number to quote');
  }
}
