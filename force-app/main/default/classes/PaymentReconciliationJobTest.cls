/**
 * ST-05, S-02. Proves the scheduled reconciliation asks Stripe for the completed checkouts in its
 * window, records each paid one, carries on to the next page when Stripe has more, and when Stripe
 * is down, logs it and stops until the next run. The household has one $120 statement.
 */
@IsTest
private class PaymentReconciliationJobTest {
  @TestSetup
  static void createData() {
    insert StewardTestData.statement(
      StewardTestData.createHousehold(),
      StewardTestData.monthStart(1),
      120.00,
      StewardTestData.STATEMENT_PAST_DUE
    );
  }

  private static Id statementId() {
    return [SELECT Id FROM Billing_Statement__c WITH SYSTEM_MODE LIMIT 1].Id;
  }

  // A test can't start a queueable from a queueable, so the job keeps each one it would start in
  // nextInTest, and the test runs it.
  private static void runScheduled() {
    new PaymentReconciliationJob().execute((SchedulableContext) null);
    PaymentReconciliationJob firstPage = PaymentReconciliationJob.nextInTest;
    Assert.isNotNull(firstPage, 'The schedule starts the first page');
    PaymentReconciliationJob.nextInTest = null;
    Test.startTest();
    firstPage.execute((QueueableContext) null);
    Test.stopTest();
  }

  @IsTest
  static void aRunRecordsThePaymentsInItsWindow() {
    StripeMock stripe = new StripeMock()
      .answer(
        'GET /v1/checkout/sessions',
        200,
        StripeMock.lastPage(
          new List<StripeMock.Session>{
            new StripeMock.Session('cs_1', statementId(), 12000).paidBy('pi_1')
          }
        )
      );
    Test.setMock(HttpCalloutMock.class, stripe);
    Long windowStart =
      Datetime.now()
        .addHours(
          -PolicySettings.getWholeNumber(
            PolicySettings.PAYMENT_RECONCILIATION_HOURS
          )
        )
        .getTime() / 1000;

    runScheduled();

    Assert.areEqual(
      1,
      [
        SELECT COUNT()
        FROM Payment__c
        WHERE External_Reference__c = 'pi_1'
        WITH SYSTEM_MODE
      ],
      'The payment the customer never came back to confirm'
    );
    String endpoint = EncodingUtil.urlDecode(
      stripe.last().getEndpoint(),
      'UTF-8'
    );
    Long asked = Long.valueOf(
      endpoint.substringAfter('created[gte]=').substringBefore('&')
    );
    Assert.isTrue(
      Math.abs(asked - windowStart) < 120,
      'Sessions from the policy\'s window: ' + endpoint
    );
    Assert.isNull(PaymentReconciliationJob.nextInTest, 'Nothing more to read');
    Assert.areEqual(
      'Succeeded',
      [SELECT Outcome__c FROM Integration_Log__c WITH SYSTEM_MODE LIMIT 1]
      .Outcome__c,
      'The call is logged'
    );
  }

  @IsTest
  static void morePagesCarryOnFromTheLastSession() {
    Test.setMock(
      HttpCalloutMock.class,
      new StripeMock()
        .answer(
          'GET /v1/checkout/sessions',
          200,
          StripeMock.pageWithMore(
            new List<StripeMock.Session>{
              new StripeMock.Session('cs_1', statementId(), 12000),
              new StripeMock.Session('cs_2', statementId(), 12000)
            }
          )
        )
    );

    runScheduled();

    Assert.isNotNull(
      PaymentReconciliationJob.nextInTest,
      'The next page is started'
    );
    Assert.areEqual(
      'cs_2',
      PaymentReconciliationJob.nextInTest.startsAfter(),
      'After the last session read'
    );
  }

  @IsTest
  static void stripeDownIsLoggedAndTheRunStops() {
    Test.setMock(
      HttpCalloutMock.class,
      new StripeMock()
        .answer(
          'GET /v1/checkout/sessions',
          503,
          StripeMock.error('api_error', null)
        )
    );

    runScheduled();

    List<Integration_Log__c> logged = [
      SELECT Operation__c, Outcome__c, Status_Code__c
      FROM Integration_Log__c
      WITH SYSTEM_MODE
      ORDER BY Name
    ];
    Assert.areEqual(2, logged.size(), 'The call and the stop: ' + logged);
    Assert.areEqual(
      'List completed sessions',
      logged[0].Operation__c,
      'The call'
    );
    Assert.areEqual(503, logged[0].Status_Code__c, 'With Stripe\'s status');
    Assert.areEqual(
      'Reconciliation stopped',
      logged[1].Operation__c,
      'Then the stop'
    );
    Assert.areEqual('Failed', logged[1].Outcome__c, 'As a failure');
    Assert.isNull(PaymentReconciliationJob.nextInTest, 'No next page');
  }

  @IsTest
  static void aJobThatEndsWithAnUnhandledErrorIsLogged() {
    new PaymentReconciliationJob.Watch(3)
      .execute(
        new Ended(
          ParentJobResult.UNHANDLED_EXCEPTION,
          new QueryException('Simulated failure')
        )
      );

    Integration_Log__c logged = [
      SELECT Operation__c, Outcome__c, Details__c
      FROM Integration_Log__c
      WITH SYSTEM_MODE
    ];
    Assert.areEqual('Reconciliation failed', logged.Operation__c, 'Logged');
    Assert.areEqual('Failed', logged.Outcome__c, 'As a failure');
    Assert.isTrue(
      logged.Details__c.startsWith('Page 3: System.QueryException'),
      'Which page, and what went wrong: ' + logged.Details__c
    );
  }

  @IsTest
  static void aJobThatEndsWellAddsNothing() {
    new PaymentReconciliationJob.Watch(1)
      .execute(new Ended(ParentJobResult.SUCCESS, null));

    Assert.areEqual(
      0,
      [SELECT COUNT() FROM Integration_Log__c WITH SYSTEM_MODE],
      'Nothing to add'
    );
  }

  // How a job ended, the way the platform tells a finalizer.
  private class Ended implements FinalizerContext {
    private final ParentJobResult result;
    private final Exception error;

    Ended(ParentJobResult result, Exception error) {
      this.result = result;
      this.error = error;
    }

    /**
     * Not needed by the watch.
     * @return null
     */
    public Id getAsyncApexJobId() {
      return null;
    }

    /**
     * The exception the job ended with.
     * @return the exception, or null
     */
    public Exception getException() {
      return error;
    }

    /**
     * Not needed by the watch.
     * @return null
     */
    public String getRequestId() {
      return null;
    }

    /**
     * How the job ended.
     * @return the result
     */
    public ParentJobResult getResult() {
      return result;
    }
  }
}
