/**
 * ST-05, S-02, S-27. Proves each Payment_Received__e becomes one Lease Payment: with its statement,
 * amount, date and Stripe's payment ID; once, however many times it arrives; never overwriting a
 * payment already recorded; and a payment the platform refuses is logged for support while the
 * rest are recorded. The household has one $120 statement and a $50 payment already recorded
 * against it.
 */
@IsTest
private class PaymentReceivedTriggerHandlerTest {
  @TestSetup
  static void createData() {
    StewardTestData.Household household = StewardTestData.createHousehold();
    Billing_Statement__c statement = StewardTestData.statement(
      household,
      StewardTestData.monthStart(1),
      120.00,
      StewardTestData.STATEMENT_PAST_DUE
    );
    insert statement;
    Payment__c existing = StewardTestData.payment(
      statement,
      50.00,
      StewardTestData.monthStart(1).addDays(-5)
    );
    existing.External_Reference__c = 'pi_existing';
    insert existing;
  }

  private static Id statementId() {
    return [SELECT Id FROM Billing_Statement__c WITH SYSTEM_MODE LIMIT 1].Id;
  }

  // A $70 payment made today, from the portal; a test changes what it's about.
  private static Payment_Received__e event(
    String statementId,
    String reference
  ) {
    return new Payment_Received__e(
      Statement_Id__c = statementId,
      Amount__c = 70.00,
      Paid_On__c = Date.today(),
      External_Reference__c = reference,
      Source__c = PaymentCheckoutService.SOURCE_PORTAL
    );
  }

  private static void deliver(List<Payment_Received__e> events) {
    Test.startTest();
    EventBus.publish(events);
    Test.stopTest();
  }

  @IsTest
  static void aPaymentIsRecordedWithItsDetails() {
    Payment_Received__e yesterdays = event(statementId(), 'pi_new');
    yesterdays.Paid_On__c = Date.today().addDays(-1);
    deliver(new List<Payment_Received__e>{ yesterdays });

    Payment__c recorded = [
      SELECT Billing_Statement__c, Amount__c, Payment_Date__c, Method__c
      FROM Payment__c
      WHERE External_Reference__c = 'pi_new'
      WITH SYSTEM_MODE
    ];
    Assert.areEqual(
      statementId(),
      recorded.Billing_Statement__c,
      'Its statement'
    );
    Assert.areEqual(70.00, recorded.Amount__c, 'Its amount');
    Assert.areEqual(
      Date.today().addDays(-1),
      recorded.Payment_Date__c,
      'Its date'
    );
    Assert.areEqual('Card', recorded.Method__c, 'Paid by card');
  }

  @IsTest
  static void theSamePaymentTwiceIsRecordedOnce() {
    deliver(
      new List<Payment_Received__e>{
        event(statementId(), 'pi_twice'),
        event(statementId(), 'pi_twice')
      }
    );

    Assert.areEqual(
      1,
      [
        SELECT COUNT()
        FROM Payment__c
        WHERE External_Reference__c = 'pi_twice'
        WITH SYSTEM_MODE
      ],
      'Once'
    );
  }

  @IsTest
  static void aPaymentAlreadyRecordedIsNeverOverwritten() {
    Payment_Received__e different = event(statementId(), 'pi_existing');
    different.Amount__c = 999.00;
    deliver(new List<Payment_Received__e>{ different });

    List<Payment__c> payments = [
      SELECT Amount__c
      FROM Payment__c
      WHERE External_Reference__c = 'pi_existing'
      WITH SYSTEM_MODE
    ];
    Assert.areEqual(1, payments.size(), 'Still one');
    Assert.areEqual(50.00, payments[0].Amount__c, 'As it was recorded');
  }

  @IsTest
  static void aRefusedPaymentIsLoggedAndTheRestRecorded() {
    Id noSuchStatement = TestIds.missing(Billing_Statement__c.SObjectType);

    deliver(
      new List<Payment_Received__e>{
        event(noSuchStatement, 'pi_orphan'),
        event(statementId(), 'pi_good')
      }
    );

    Assert.areEqual(
      1,
      [
        SELECT COUNT()
        FROM Payment__c
        WHERE External_Reference__c = 'pi_good'
        WITH SYSTEM_MODE
      ],
      'The good one is recorded'
    );
    Integration_Log__c logged = [
      SELECT Operation__c, Outcome__c, Provider_Reference__c, Details__c
      FROM Integration_Log__c
      WITH SYSTEM_MODE
      LIMIT 1
    ];
    Assert.areEqual(
      'Record payment',
      logged.Operation__c,
      'Logged as a payment to record'
    );
    Assert.areEqual('Failed', logged.Outcome__c, 'That failed');
    Assert.areEqual('pi_orphan', logged.Provider_Reference__c, 'Which one');
    Assert.isNotNull(logged.Details__c, 'With the platform\'s reason');
  }

  @IsTest
  static void aDateAfterTodayIsRecordedAsToday() {
    Payment_Received__e tomorrows = event(statementId(), 'pi_tomorrow');
    tomorrows.Paid_On__c = Date.today().addDays(1);
    deliver(new List<Payment_Received__e>{ tomorrows });

    Payment__c recorded = [
      SELECT Payment_Date__c
      FROM Payment__c
      WHERE External_Reference__c = 'pi_tomorrow'
      WITH SYSTEM_MODE
    ];
    Assert.isTrue(
      recorded.Payment_Date__c <= Date.today(),
      'Never in the future, which Accord refuses: ' + recorded.Payment_Date__c
    );
  }
}
