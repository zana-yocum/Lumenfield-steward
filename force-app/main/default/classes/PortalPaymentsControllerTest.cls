/**
 * ST-05, ST-12, NFR-07. Proves the portal's Pay button and return page work for the logged-in
 * customer's own statements only, and that every failure gives a reference to quote, never the
 * error, with the action log naming the integration log that holds Stripe's answer.
 *
 * Each household has a $120 statement past due since last month and a customer user. All data is
 * made in the setup, because Salesforce refuses a callout after a save in the same test.
 */
@IsTest
private class PortalPaymentsControllerTest {
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

  private static Id statementOf(Integer i) {
    return [
      SELECT Id
      FROM Billing_Statement__c
      WHERE Account__c = :household(i)
      WITH SYSTEM_MODE
      LIMIT 1
    ]
    .Id;
  }

  private static User customer(Integer i) {
    return [
      SELECT Id
      FROM User
      WHERE AccountId = :household(i) AND IsActive = TRUE
      LIMIT 1
    ];
  }

  @IsTest
  static void aCustomerStartsPayingTheirOwnStatement() {
    Id statementId = statementOf(0);
    Test.setMock(
      HttpCalloutMock.class,
      new StripeMock()
        .answer(
          'POST /v1/checkout/sessions',
          200,
          new StripeMock.Session('cs_test_1', statementId, 12000).json()
        )
    );
    User customer = customer(0);

    PaymentCheckoutService.Checkout result;
    Test.startTest();
    System.runAs(customer) {
      result = PortalPaymentsController.startPayment(statementId);
    }
    Test.stopTest();

    Assert.areEqual(
      StewardOutcome.COMPLETED,
      result.outcome,
      'Completed: ' + result.reasonCode
    );
    Assert.areEqual(
      'https://checkout.stripe.com/c/pay/cs_test_1',
      result.checkoutUrl,
      'Stripe\'s page'
    );
    Assert.areEqual(
      'Succeeded',
      [SELECT Outcome__c FROM Integration_Log__c WITH SYSTEM_MODE LIMIT 1]
      .Outcome__c,
      'The call is logged'
    );
  }

  @IsTest
  static void anotherHouseholdsStatementIsNotFound() {
    StripeMock stripe = new StripeMock();
    Test.setMock(HttpCalloutMock.class, stripe);
    Id someoneElses = statementOf(1);
    User customer = customer(0);

    PaymentCheckoutService.Checkout result;
    System.runAs(customer) {
      result = PortalPaymentsController.startPayment(someoneElses);
    }

    Assert.areEqual(StewardOutcome.NOT_FOUND, result.reasonCode, 'Not found');
    Assert.isTrue(stripe.requests.isEmpty(), 'Stripe never hears of it');
  }

  @IsTest
  static void someoneWhoIsntACustomerIsTurnedAway() {
    PaymentCheckoutService.Checkout started = PortalPaymentsController.startPayment(
      statementOf(0)
    );
    PaymentCheckoutService.Confirmation confirmed = PortalPaymentsController.confirmPayment(
      'cs_test_1'
    );

    Assert.areEqual(
      StewardOutcome.INVALID_REQUEST,
      started.reasonCode,
      'Paying is for customers'
    );
    Assert.areEqual(
      StewardOutcome.INVALID_REQUEST,
      confirmed.reasonCode,
      'So is confirming'
    );
  }

  @IsTest
  static void noStatementIsNotFound() {
    User customer = customer(0);

    PaymentCheckoutService.Checkout result;
    System.runAs(customer) {
      result = PortalPaymentsController.startPayment(null);
    }

    Assert.areEqual(StewardOutcome.NOT_FOUND, result.reasonCode, 'Not found');
  }

  @IsTest
  static void stripeDownGivesAReferenceAndTheLogNamesStripesAnswer() {
    Test.setMock(
      HttpCalloutMock.class,
      new StripeMock()
        .answer(
          'POST /v1/checkout/sessions',
          500,
          StripeMock.error('api_error', null)
        )
    );
    Id statementId = statementOf(0);
    User customer = customer(0);

    PaymentCheckoutService.Checkout result;
    Test.startTest();
    System.runAs(customer) {
      result = PortalPaymentsController.startPayment(statementId);
    }
    Test.stopTest();

    Assert.areEqual(StewardOutcome.FAILED, result.outcome, 'Failed');
    Assert.isNotNull(result.reference, 'A number to quote');
    Assert.isNull(
      result.failureDetail,
      'Stripe\'s error never reaches the page'
    );
    Agent_Action_Log__c logged = [
      SELECT Details__c
      FROM Agent_Action_Log__c
      WHERE Name = :result.reference
      WITH SYSTEM_MODE
    ];
    String integrationLog = [
      SELECT Name
      FROM Integration_Log__c
      WITH SYSTEM_MODE
      LIMIT 1
    ]
    .Name;
    Assert.isTrue(
      logged.Details__c.contains('PROVIDER_UNAVAILABLE') &&
      logged.Details__c.contains(integrationLog),
      'The log says why and where Stripe\'s answer is: ' + logged.Details__c
    );
  }

  // What the action log says went wrong, for a failing assertion's message.
  private static String loggedFailures() {
    List<String> details = new List<String>();
    for (Agent_Action_Log__c logged : [
      SELECT Details__c
      FROM Agent_Action_Log__c
      WITH SYSTEM_MODE
      ORDER BY Name
      LIMIT 10
    ]) {
      details.add(logged.Details__c);
    }
    return String.join(details, ' | ');
  }

  @IsTest
  static void aCustomerComingBackFromAPaidCheckoutHasItRecorded() {
    Id statementId = statementOf(0);
    Test.setMock(
      HttpCalloutMock.class,
      new StripeMock()
        .answer(
          'GET /v1/checkout/sessions/cs_test_1',
          200,
          new StripeMock.Session('cs_test_1', statementId, 12000)
            .paidBy('pi_test_1')
            .json()
        )
    );
    User customer = customer(0);

    PaymentCheckoutService.Confirmation result;
    Test.startTest();
    System.runAs(customer) {
      result = PortalPaymentsController.confirmPayment('cs_test_1');
    }
    Test.stopTest();

    Assert.areEqual(
      StewardOutcome.COMPLETED,
      result.outcome,
      'Completed: ' + result.reasonCode + ' ' + loggedFailures()
    );
    Assert.areEqual(120.00, result.amount, 'What was paid');
    Assert.isTrue(result.recorded, 'On the statement now');
    Assert.areEqual(
      1,
      [
        SELECT COUNT()
        FROM Payment__c
        WHERE External_Reference__c = 'pi_test_1'
        WITH SYSTEM_MODE
      ],
      'Recorded on the statement'
    );
  }

  @IsTest
  static void noAnswerOnTheWayBackGivesAReference() {
    StripeMock stripe = new StripeMock();
    stripe.timesOut = true;
    Test.setMock(HttpCalloutMock.class, stripe);
    User customer = customer(0);

    PaymentCheckoutService.Confirmation result;
    Test.startTest();
    System.runAs(customer) {
      result = PortalPaymentsController.confirmPayment('cs_test_1');
    }
    Test.stopTest();

    Assert.areEqual(StewardOutcome.FAILED, result.outcome, 'Failed');
    Assert.isNotNull(result.reference, 'A number to quote');
  }

  @IsTest
  static void anythingUnexpectedGivesAReferenceNotTheError() {
    Id statementId = statementOf(0);
    User customer = customer(0);
    PortalHousehold.simulatedFailure = new QueryException('Simulated failure');

    PaymentCheckoutService.Checkout started;
    PaymentCheckoutService.Confirmation confirmed;
    System.runAs(customer) {
      started = PortalPaymentsController.startPayment(statementId);
      confirmed = PortalPaymentsController.confirmPayment('cs_test_1');
    }

    Assert.areEqual(StewardOutcome.FAILED, started.outcome, 'Failed');
    Assert.isNotNull(started.reference, 'A number to quote');
    Assert.areEqual(StewardOutcome.FAILED, confirmed.outcome, 'Failed');
    Assert.isNotNull(confirmed.reference, 'A number to quote');
  }
}
