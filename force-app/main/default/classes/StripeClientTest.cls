/**
 * ST-05, S-02, NFR-07. Proves StripeClient sends what Stripe expects and nothing it shouldn't:
 * the statement as the client reference, the amount in cents, the return address with Stripe's
 * session placeholder, and an idempotency key, through the named credential so no key is in the
 * request. Every call is logged with its status and duration, and every kind of failure throws
 * with Stripe's error type and code. No test calls out: StripeMock answers.
 */
@IsTest
private class StripeClientTest {
  @TestSetup
  static void createData() {
    StewardTestData.Household household = StewardTestData.createHousehold();
    insert StewardTestData.statement(
      household,
      StewardTestData.monthStart(0),
      55.00,
      StewardTestData.STATEMENT_PAST_DUE
    );
  }

  private static Id statementId() {
    return [SELECT Id FROM Billing_Statement__c WITH SYSTEM_MODE LIMIT 1].Id;
  }

  private static StripeClient.CheckoutRequest request() {
    StripeClient.CheckoutRequest request = new StripeClient.CheckoutRequest();
    request.statementId = statementId();
    request.description = 'Lumenfield lease payment, statement STMT-00012';
    request.amountCents = 5500;
    request.successUrl = 'https://example.com/statement?recordId=x&c__session_id={CHECKOUT_SESSION_ID}';
    request.cancelUrl = 'https://example.com/statement?recordId=x&c__payment=cancelled';
    return request;
  }

  @IsTest
  static void aCheckoutSessionAsksForTheBalanceOfOneStatement() {
    Id statement = statementId();
    StripeMock stripe = new StripeMock()
      .answer(
        'POST /v1/checkout/sessions',
        200,
        new StripeMock.Session('cs_test_1', statement, 5500).json()
      );
    Test.setMock(HttpCalloutMock.class, stripe);

    Test.startTest();
    StripeClient.CheckoutSession session = new StripeClient()
      .createCheckoutSession(request());
    Test.stopTest();

    Assert.areEqual('cs_test_1', session.id, 'The session');
    Assert.areEqual(
      'https://checkout.stripe.com/c/pay/cs_test_1',
      session.url,
      'Stripe\'s page'
    );
    HttpRequest sent = stripe.last();
    Assert.areEqual(
      'callout:Stripe_API/v1/checkout/sessions',
      sent.getEndpoint(),
      'Through the named credential, so no key is in the code'
    );
    Assert.isNull(
      sent.getHeader('Authorization'),
      'Steward never sets the key'
    );
    Assert.isTrue(
      sent.getHeader('Idempotency-Key')
        .startsWith('steward-checkout-' + statement + '-5500-'),
      'An idempotency key for this statement and amount'
    );
    String body = EncodingUtil.urlDecode(sent.getBody(), 'UTF-8');
    Assert.isTrue(body.contains('client_reference_id=' + statement), body);
    Assert.isTrue(
      body.contains('line_items[0][price_data][unit_amount]=5500'),
      'The balance in cents: ' + body
    );
    Assert.isTrue(
      body.contains('session_id={CHECKOUT_SESSION_ID}'),
      'Stripe fills in the session on the way back'
    );
    Assert.isFalse(body.contains('email'), 'No contact details go to Stripe');
    Integration_Log__c logged = savedLog();
    Assert.areEqual('Succeeded', logged.Outcome__c, 'Logged as a success');
    Assert.areEqual(200, logged.Status_Code__c, 'With its status');
    Assert.areEqual(
      'cs_test_1',
      logged.Provider_Reference__c,
      'And the session'
    );
    Assert.areEqual(
      statement,
      logged.Billing_Statement__c,
      'For the statement'
    );
  }

  @IsTest
  static void stripeRefusingThrowsWithItsErrorAndIsLogged() {
    Test.setMock(
      HttpCalloutMock.class,
      new StripeMock()
        .answer(
          'POST /v1/checkout/sessions',
          402,
          StripeMock.error('invalid_request_error', 'amount_too_small')
        )
    );

    Test.startTest();
    try {
      new StripeClient().createCheckoutSession(request());
      Assert.fail('Expected a StripeException');
    } catch (StripeClient.StripeException refused) {
      Assert.isTrue(refused.getMessage().contains('402'), refused.getMessage());
    }
    Test.stopTest();

    Integration_Log__c logged = savedLog();
    Assert.areEqual('Failed', logged.Outcome__c, 'Logged as a failure');
    Assert.areEqual(402, logged.Status_Code__c, 'With Stripe\'s status');
    Assert.isTrue(
      logged.Details__c.contains('invalid_request_error / amount_too_small'),
      'And Stripe\'s error type and code: ' + logged.Details__c
    );
  }

  @IsTest
  static void noAnswerThrowsAndIsLoggedWithoutAStatus() {
    StripeMock stripe = new StripeMock();
    stripe.timesOut = true;
    Test.setMock(HttpCalloutMock.class, stripe);

    Test.startTest();
    try {
      new StripeClient().getCheckoutSession('cs_test_1', null);
      Assert.fail('Expected a StripeException');
    } catch (StripeClient.StripeException noAnswer) {
      Assert.areEqual(
        'No answer from Stripe.',
        noAnswer.getMessage(),
        'Said plainly'
      );
    }
    Test.stopTest();

    Integration_Log__c logged = savedLog();
    Assert.areEqual('Failed', logged.Outcome__c, 'A failure');
    Assert.isNull(logged.Status_Code__c, 'No status: nothing came back');
    Assert.isTrue(logged.Details__c.startsWith('No answer'), logged.Details__c);
  }

  @IsTest
  static void anAnswerThatIsntJsonIsAFailure() {
    Test.setMock(
      HttpCalloutMock.class,
      new StripeMock()
        .answer('GET /v1/checkout/sessions/cs_test_1', 200, '<html>')
    );

    Test.startTest();
    try {
      new StripeClient().getCheckoutSession('cs_test_1', null);
      Assert.fail('Expected a StripeException');
    } catch (StripeClient.StripeException unreadable) {
      Assert.isTrue(
        unreadable.getMessage().contains('isn\'t JSON'),
        unreadable.getMessage()
      );
    }
    Test.stopTest();
  }

  @IsTest
  static void aSessionReadBackSaysWhetherItWasPaid() {
    Id statement = statementId();
    Map<String, Object> fields = new StripeMock.Session(
        'cs_test_1',
        statement,
        5500
      )
      .paidBy('pi_test_1')
      .fields();
    // Stripe can send the payment as an object when it's expanded.
    fields.put(
      'payment_intent',
      new Map<String, Object>{ 'id' => 'pi_test_1' }
    );
    Test.setMock(
      HttpCalloutMock.class,
      new StripeMock()
        .answer(
          'GET /v1/checkout/sessions/cs_test_1',
          200,
          JSON.serialize(fields)
        )
    );

    Test.startTest();
    StripeClient.CheckoutSession session = new StripeClient()
      .getCheckoutSession('cs_test_1', null);
    Test.stopTest();

    Assert.areEqual(StripeClient.PAID, session.paymentStatus, 'Paid');
    Assert.areEqual('pi_test_1', session.paymentIntent, 'The payment\'s ID');
    Assert.areEqual(5500L, session.amountTotal, 'In cents');
    Assert.areEqual(
      String.valueOf(statement),
      session.clientReferenceId,
      'For the statement'
    );
    Assert.areEqual(
      statement,
      savedLog().Billing_Statement__c,
      'Logged against it'
    );
  }

  @IsTest
  static void completedSessionsComeAPageAtATime() {
    Id statement = statementId();
    StripeMock stripe = new StripeMock()
      .answer(
        'GET /v1/checkout/sessions',
        200,
        StripeMock.pageWithMore(
          new List<StripeMock.Session>{
            new StripeMock.Session('cs_test_1', statement, 5500)
              .paidBy('pi_test_1'),
            new StripeMock.Session('cs_test_2', statement, 4000)
              .paidBy('pi_test_2')
          }
        )
      );
    Test.setMock(HttpCalloutMock.class, stripe);

    Test.startTest();
    StripeClient.SessionPage page = new StripeClient()
      .listCompletedSessions(1700000000, 'cs_test_0');
    Test.stopTest();

    Assert.areEqual(2, page.sessions.size(), 'Both sessions');
    Assert.isTrue(page.hasMore, 'And more to come');
    String endpoint = EncodingUtil.urlDecode(
      stripe.last().getEndpoint(),
      'UTF-8'
    );
    Assert.isTrue(endpoint.contains('status=complete'), endpoint);
    Assert.isTrue(endpoint.contains('created[gte]=1700000000'), endpoint);
    Assert.isTrue(endpoint.contains('starting_after=cs_test_0'), endpoint);
    Assert.areEqual('2 sessions', savedLog().Details__c, 'The count is logged');
  }

  private static Integration_Log__c savedLog() {
    IntegrationLogger.save();
    return [
      SELECT
        Outcome__c,
        Status_Code__c,
        Duration_Ms__c,
        Provider__c,
        Provider_Reference__c,
        Billing_Statement__c,
        Details__c
      FROM Integration_Log__c
      WITH SYSTEM_MODE
      ORDER BY Name DESC
      LIMIT 1
    ];
  }
}
