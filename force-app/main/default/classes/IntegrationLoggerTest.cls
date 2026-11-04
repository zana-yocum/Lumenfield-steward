/**
 * ST-05, S-28, NFR-07. Proves calls kept in memory are saved together and read back by number,
 * that long text is cut to fit and card numbers are removed before saving, that nothing is saved
 * when there's nothing to save, and that a customer, who has no access to the log, still gets their
 * calls recorded.
 */
@IsTest
private class IntegrationLoggerTest {
  @TestSetup
  static void createData() {
    PortalTestData.giveRunningUserARole();
    PortalTestData.createCustomers(
      StewardTestData.createHouseholds(1, StewardTestData.ACCOUNT_DELINQUENT)
    );
  }

  @IsTest
  static void callsAreSavedTogetherWithTheirNumbers() {
    IntegrationLogger.Call created = new IntegrationLogger.Call(
      'Stripe',
      'Create checkout session'
    );
    created.outcome = IntegrationLogger.SUCCEEDED;
    created.statusCode = 200;
    created.durationMs = 312;
    created.providerReference = 'cs_test_1';
    IntegrationLogger.Call failed = new IntegrationLogger.Call(
      'Stripe',
      'Read checkout session'
    );
    failed.outcome = IntegrationLogger.FAILED;
    failed.details = 'Card 4242 4242 4242 4242 ' + 'x'.repeat(2100);
    IntegrationLogger.record(created);
    IntegrationLogger.record(failed);
    IntegrationLogger.record(null);

    Assert.areEqual(2, IntegrationLogger.pendingCount(), 'Two calls waiting');
    Map<Id, String> numbers = IntegrationLogger.save();

    Assert.areEqual(2, numbers.size(), 'Both saved');
    Assert.areEqual(
      0,
      IntegrationLogger.pendingCount(),
      'Nothing left waiting'
    );
    for (String logNumber : numbers.values()) {
      Assert.isTrue(logNumber.startsWith('INT-'), 'Numbered: ' + logNumber);
    }
    Integration_Log__c saved = [
      SELECT Outcome__c, Details__c
      FROM Integration_Log__c
      WHERE Operation__c = 'Read checkout session'
      WITH SYSTEM_MODE
    ];
    Assert.areEqual('Failed', saved.Outcome__c, 'Its outcome');
    Assert.areEqual(2000, saved.Details__c.length(), 'Cut to fit');
    Assert.isFalse(
      saved.Details__c.contains('4242 4242 4242 4242'),
      'No card number is ever saved'
    );
  }

  @IsTest
  static void nothingToSaveSavesNothing() {
    Map<Id, String> numbers = IntegrationLogger.save();

    Assert.isTrue(numbers.isEmpty(), 'Nothing');
    Assert.areEqual(0, Limits.getDmlStatements(), 'Not even an empty save');
  }

  @IsTest
  static void aCustomersCallIsRecordedThoughTheyCantReadTheLog() {
    User customer = [
      SELECT Id
      FROM User
      WHERE Profile.Name = :PortalTestData.CUSTOMER_PROFILE AND IsActive = TRUE
      LIMIT 1
    ];

    Map<Id, String> numbers;
    Boolean canRead;
    System.runAs(customer) {
      IntegrationLogger.Call call = new IntegrationLogger.Call(
        'Stripe',
        'Create checkout session'
      );
      call.outcome = IntegrationLogger.SUCCEEDED;
      IntegrationLogger.record(call);
      numbers = IntegrationLogger.save();
      canRead = Schema.SObjectType.Integration_Log__c.isAccessible();
    }

    Assert.areEqual(1, numbers.size(), 'Recorded');
    Assert.isFalse(canRead, 'Though the customer can\'t read the log');
  }
}
