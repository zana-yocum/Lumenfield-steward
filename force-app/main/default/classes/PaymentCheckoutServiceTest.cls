/**
 * ST-05, ST-12, S-02, NFR-07. Proves paying online asks Stripe for exactly the household's own
 * balance, records a payment only when Stripe says it was paid, records it once however many times
 * it's seen, and never touches another household's statement. Stripe is StripeMock; no test calls
 * out.
 *
 * All data is made in the setup, because Salesforce refuses a callout after a save in the same
 * test. The first household has a $95 statement past due since two months ago, a $120 statement
 * past due since last month, and a $120 statement paid in full. The second has an $80 statement.
 * Each household has a customer user.
 */
@IsTest
private class PaymentCheckoutServiceTest {
  @TestSetup
  static void createData() {
    PortalTestData.giveRunningUserARole();
    List<StewardTestData.Household> households = StewardTestData.createHouseholds(
      2,
      StewardTestData.ACCOUNT_DELINQUENT
    );
    List<Billing_Statement__c> statements = new List<Billing_Statement__c>{
      StewardTestData.statement(
        households[0],
        StewardTestData.monthStart(2),
        95.00,
        StewardTestData.STATEMENT_PAST_DUE
      ),
      StewardTestData.statement(
        households[0],
        StewardTestData.monthStart(1),
        120.00,
        StewardTestData.STATEMENT_PAST_DUE
      ),
      StewardTestData.statement(
        households[0],
        StewardTestData.monthStart(3),
        120.00,
        StewardTestData.STATEMENT_PAID
      ),
      StewardTestData.statement(
        households[1],
        StewardTestData.monthStart(1),
        80.00,
        StewardTestData.STATEMENT_PAST_DUE
      )
    };
    insert statements;
    insert StewardTestData.payment(
      statements[2],
      120.00,
      StewardTestData.monthStart(3).addDays(-1)
    );
    PortalTestData.createCustomers(households);
  }

  private static Id household(Integer i) {
    return StewardTestData.existingHouseholds()[i].account.Id;
  }

  private static Billing_Statement__c statement(Integer i, Decimal amountDue) {
    return [
      SELECT Id, Name, Balance__c
      FROM Billing_Statement__c
      WHERE Account__c = :household(i) AND Amount_Due__c = :amountDue
      WITH SYSTEM_MODE
      ORDER BY Due_Date__c DESC
      LIMIT 1
    ];
  }

  private static User customerOf(Id householdId) {
    return [
      SELECT Id
      FROM User
      WHERE AccountId = :householdId AND IsActive = TRUE
      LIMIT 1
    ];
  }

  @IsTest
  static void aCustomerGetsStripesPageForTheirStatementsBalance() {
    Billing_Statement__c lastMonths = statement(0, 120.00);
    StripeMock stripe = new StripeMock()
      .answer(
        'POST /v1/checkout/sessions',
        200,
        new StripeMock.Session('cs_test_1', lastMonths.Id, 12000).json()
      );
    Test.setMock(HttpCalloutMock.class, stripe);

    PaymentCheckoutService.Checkout result;
    Test.startTest();
    System.runAs(customerOf(household(0))) {
      result = PaymentCheckoutService.startCheckout(
        household(0),
        lastMonths.Id
      );
    }
    Test.stopTest();

    Assert.areEqual(
      StewardOutcome.COMPLETED,
      result.outcome,
      'Completed: ' + result.reasonCode + ' ' + result.failureDetail
    );
    Assert.areEqual(
      'https://checkout.stripe.com/c/pay/cs_test_1',
      result.checkoutUrl,
      'Stripe\'s page'
    );
    Assert.areEqual(lastMonths.Balance__c, result.amount, 'The balance');
    Assert.areEqual(lastMonths.Name, result.statementNumber, 'Its number');
    String body = EncodingUtil.urlDecode(stripe.last().getBody(), 'UTF-8');
    Assert.isTrue(
      body.contains('line_items[0][price_data][unit_amount]=12000'),
      'The balance in cents: ' + body
    );
    Assert.isTrue(
      body.contains(
        '/statement?recordId=' +
          lastMonths.Id +
          '&c__session_id={CHECKOUT_SESSION_ID}'
      ),
      'Back to the statement\'s own page, with the session: ' + body
    );
  }

  @IsTest
  static void anotherHouseholdsStatementIsNotFoundAndStripeIsNeverAsked() {
    StripeMock stripe = new StripeMock();
    Test.setMock(HttpCalloutMock.class, stripe);
    Id someoneElses = statement(1, 80.00).Id;

    PaymentCheckoutService.Checkout result;
    System.runAs(customerOf(household(0))) {
      result = PaymentCheckoutService.startCheckout(household(0), someoneElses);
    }

    Assert.areEqual(StewardOutcome.DECLINED_POLICY, result.outcome, 'Declined');
    Assert.areEqual(StewardOutcome.NOT_FOUND, result.reasonCode, 'Not found');
    Assert.isTrue(stripe.requests.isEmpty(), 'Stripe never hears of it');
    Assert.isNull(result.amount, 'Nothing about it comes back');
  }

  @IsTest
  static void aStatementWithNothingOwedIsDeclined() {
    StripeMock stripe = new StripeMock();
    Test.setMock(HttpCalloutMock.class, stripe);
    Billing_Statement__c paid = [
      SELECT Id
      FROM Billing_Statement__c
      WHERE Account__c = :household(0) AND Balance__c <= 0
      WITH SYSTEM_MODE
      LIMIT 1
    ];

    PaymentCheckoutService.Checkout result = PaymentCheckoutService.startCheckout(
      household(0),
      paid.Id
    );

    Assert.areEqual(StewardOutcome.DECLINED_POLICY, result.outcome, 'Declined');
    Assert.areEqual(
      PaymentCheckoutService.NOTHING_OWED,
      result.reasonCode,
      'Nothing owed'
    );
    Assert.isTrue(stripe.requests.isEmpty(), 'Stripe isn\'t asked');
  }

  @IsTest
  static void noStatementMeansTheOldestWithABalance() {
    Billing_Statement__c oldest = statement(0, 95.00);
    Test.setMock(
      HttpCalloutMock.class,
      new StripeMock()
        .answer(
          'POST /v1/checkout/sessions',
          200,
          new StripeMock.Session('cs_test_1', oldest.Id, 9500).json()
        )
    );

    Test.startTest();
    PaymentCheckoutService.Checkout result = PaymentCheckoutService.startCheckout(
      household(0),
      null
    );
    Test.stopTest();

    Assert.areEqual(StewardOutcome.COMPLETED, result.outcome, 'Completed');
    Assert.areEqual(
      oldest.Name,
      result.statementNumber,
      'The oldest unpaid one'
    );
  }

  @IsTest
  static void stripeDownIsAFailureWithStripesErrorForTheLog() {
    Test.setMock(
      HttpCalloutMock.class,
      new StripeMock()
        .answer(
          'POST /v1/checkout/sessions',
          500,
          StripeMock.error('api_error', null)
        )
    );

    Test.startTest();
    PaymentCheckoutService.Checkout result = PaymentCheckoutService.startCheckout(
      household(0),
      statement(0, 120.00).Id
    );
    IntegrationLogger.save();
    Test.stopTest();

    Assert.areEqual(StewardOutcome.FAILED, result.outcome, 'Failed');
    Assert.areEqual(
      PaymentCheckoutService.PROVIDER_UNAVAILABLE,
      result.reasonCode,
      'Stripe unavailable'
    );
    Assert.isTrue(result.failureDetail.contains('500'), result.failureDetail);
    Assert.isNull(result.checkoutUrl, 'No page');
    Assert.areEqual(
      1,
      [
        SELECT COUNT()
        FROM Integration_Log__c
        WHERE Outcome__c = 'Failed'
        WITH SYSTEM_MODE
      ],
      'Logged for support'
    );
  }

  @IsTest
  static void aPaidSessionIsRecordedAsAPayment() {
    Billing_Statement__c lastMonths = statement(0, 120.00);
    Test.setMock(
      HttpCalloutMock.class,
      new StripeMock()
        .answer(
          'GET /v1/checkout/sessions/cs_test_1',
          200,
          new StripeMock.Session('cs_test_1', lastMonths.Id, 12000)
            .paidBy('pi_test_1')
            .json()
        )
    );

    PaymentCheckoutService.Confirmation result;
    Test.startTest();
    System.runAs(customerOf(household(0))) {
      result = PaymentCheckoutService.confirm(household(0), 'cs_test_1');
    }
    Test.stopTest();

    Assert.areEqual(
      StewardOutcome.COMPLETED,
      result.outcome,
      'Completed: ' + result.reasonCode + ' ' + result.failureDetail
    );
    Assert.areEqual(120.00, result.amount, 'What Stripe says was paid');
    Assert.areEqual(lastMonths.Id, result.statementId, 'On the statement');
    Payment__c recorded = [
      SELECT Billing_Statement__c, Amount__c, Method__c, Payment_Date__c
      FROM Payment__c
      WHERE External_Reference__c = 'pi_test_1'
      WITH SYSTEM_MODE
    ];
    Assert.areEqual(
      lastMonths.Id,
      recorded.Billing_Statement__c,
      'On that statement'
    );
    Assert.areEqual(120.00, recorded.Amount__c, 'For the amount paid');
    Assert.areEqual('Card', recorded.Method__c, 'By card');
    Assert.isTrue(
      Math.abs(recorded.Payment_Date__c.daysBetween(Date.today())) <= 1,
      'Today, in the org\'s time zone: ' + recorded.Payment_Date__c
    );
  }

  @IsTest
  static void anUnpaidSessionRecordsNothing() {
    Billing_Statement__c lastMonths = statement(0, 120.00);
    Test.setMock(
      HttpCalloutMock.class,
      new StripeMock()
        .answer(
          'GET /v1/checkout/sessions/cs_test_1',
          200,
          new StripeMock.Session('cs_test_1', lastMonths.Id, 12000).json()
        )
    );

    Test.startTest();
    PaymentCheckoutService.Confirmation result = PaymentCheckoutService.confirm(
      household(0),
      'cs_test_1'
    );
    Test.stopTest();

    Assert.areEqual(StewardOutcome.DECLINED_POLICY, result.outcome, 'Declined');
    Assert.areEqual(
      PaymentCheckoutService.NOT_PAID,
      result.reasonCode,
      'Not paid'
    );
    Assert.areEqual(
      0,
      [
        SELECT COUNT()
        FROM Payment__c
        WHERE Billing_Statement__c = :lastMonths.Id
        WITH SYSTEM_MODE
      ],
      'Nothing recorded, so the statement stays unpaid'
    );
  }

  @IsTest
  static void anotherHouseholdsSessionIsNotFoundAndNothingIsRecorded() {
    Billing_Statement__c someoneElses = statement(1, 80.00);
    Test.setMock(
      HttpCalloutMock.class,
      new StripeMock()
        .answer(
          'GET /v1/checkout/sessions/cs_test_9',
          200,
          new StripeMock.Session('cs_test_9', someoneElses.Id, 8000)
            .paidBy('pi_test_9')
            .json()
        )
    );

    PaymentCheckoutService.Confirmation result;
    Test.startTest();
    System.runAs(customerOf(household(0))) {
      result = PaymentCheckoutService.confirm(household(0), 'cs_test_9');
    }
    Test.stopTest();

    Assert.areEqual(StewardOutcome.NOT_FOUND, result.reasonCode, 'Not found');
    Assert.isNull(result.amount, 'Nothing about it comes back');
    Assert.areEqual(
      0,
      [
        SELECT COUNT()
        FROM Payment__c
        WHERE External_Reference__c = 'pi_test_9'
        WITH SYSTEM_MODE
      ],
      'Nothing recorded from someone else\'s session'
    );
  }

  @IsTest
  static void aSessionIdThatIsntOneIsRefused() {
    StripeMock stripe = new StripeMock();
    Test.setMock(HttpCalloutMock.class, stripe);

    PaymentCheckoutService.Confirmation result = PaymentCheckoutService.confirm(
      household(0),
      '../../v1/customers'
    );

    Assert.areEqual(
      StewardOutcome.INVALID_REQUEST,
      result.reasonCode,
      'Refused'
    );
    Assert.isTrue(stripe.requests.isEmpty(), 'Stripe isn\'t asked');
  }

  @IsTest
  static void noAnswerOnTheWayBackIsAFailure() {
    StripeMock stripe = new StripeMock();
    stripe.timesOut = true;
    Test.setMock(HttpCalloutMock.class, stripe);

    Test.startTest();
    PaymentCheckoutService.Confirmation result = PaymentCheckoutService.confirm(
      household(0),
      'cs_test_1'
    );
    Test.stopTest();

    Assert.areEqual(StewardOutcome.FAILED, result.outcome, 'Failed');
    Assert.areEqual(
      PaymentCheckoutService.PROVIDER_UNAVAILABLE,
      result.reasonCode,
      'Stripe unavailable'
    );
  }

  @IsTest
  static void reconciliationRecordsEveryPaidSessionForAStatementOnce() {
    Billing_Statement__c lastMonths = statement(0, 120.00);
    Billing_Statement__c someoneElses = statement(1, 80.00);
    Test.setMock(
      HttpCalloutMock.class,
      new StripeMock()
        .answer(
          'GET /v1/checkout/sessions',
          200,
          StripeMock.pageWithMore(
            new List<StripeMock.Session>{
              new StripeMock.Session('cs_r1', lastMonths.Id, 12000)
                .paidBy('pi_r1'),
              new StripeMock.Session('cs_r2', someoneElses.Id, 8000)
                .paidBy('pi_r2'),
              new StripeMock.Session('cs_r3', lastMonths.Id, 12000),
              new StripeMock.Session('cs_r4', 'not-a-statement', 500)
                .paidBy('pi_r4'),
              new StripeMock.Session('cs_r5', lastMonths.Id, 12000)
                .paidBy('pi_r1')
            }
          )
        )
    );

    Test.startTest();
    PaymentCheckoutService.Reconciliation result = PaymentCheckoutService.reconcile(
      1700000000,
      null
    );
    Test.stopTest();

    Assert.areEqual(5, result.sessionsRead, 'Every session read');
    Assert.areEqual(
      3,
      result.paymentsPublished,
      'The paid ones for a statement'
    );
    Assert.isTrue(result.hasMore, 'More to come');
    Assert.areEqual(
      'cs_r5',
      result.lastSessionId,
      'Where the next page starts'
    );
    Assert.areEqual(
      1,
      [
        SELECT COUNT()
        FROM Payment__c
        WHERE External_Reference__c = 'pi_r1'
        WITH SYSTEM_MODE
      ],
      'A payment seen twice is recorded once'
    );
    Assert.areEqual(
      1,
      [
        SELECT COUNT()
        FROM Payment__c
        WHERE External_Reference__c = 'pi_r2'
        WITH SYSTEM_MODE
      ],
      'Every household\'s payment is recorded'
    );
    Assert.areEqual(
      0,
      [
        SELECT COUNT()
        FROM Payment__c
        WHERE External_Reference__c = 'pi_r4'
        WITH SYSTEM_MODE
      ],
      'Nothing without a statement'
    );
  }
}
