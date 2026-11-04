/**
 * ST-05, S-02, S-27. Proves each payment Stripe confirmed becomes one Lease Payment: with its
 * statement, amount, date and Stripe's payment ID; once, however many times it's confirmed; never
 * overwriting a payment already recorded; and a payment the platform refuses is noted for support
 * while the rest are recorded. The household has one $120 statement and a $50 payment already
 * recorded against it.
 */
@IsTest
private class PaymentRecorderTest {
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

  // A $70 card payment made today; a test changes what it's about.
  private static Payment__c confirmed(Id statementId, String reference) {
    return new Payment__c(
      Billing_Statement__c = statementId,
      Amount__c = 70.00,
      Payment_Date__c = Date.today(),
      Method__c = CheckoutPayments.METHOD_CARD,
      External_Reference__c = reference
    );
  }

  private static PaymentRecorder.Recording record(List<Payment__c> payments) {
    return PaymentRecorder.record(
      payments,
      PaymentCheckoutService.SOURCE_PORTAL
    );
  }

  @IsTest
  static void aPaymentIsRecordedWithItsDetails() {
    Payment__c yesterdays = confirmed(statementId(), 'pi_new');
    yesterdays.Payment_Date__c = Date.today().addDays(-1);

    PaymentRecorder.Recording result = record(
      new List<Payment__c>{ yesterdays }
    );

    Assert.areEqual(1, result.recorded, 'Recorded');
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
    PaymentRecorder.Recording result = record(
      new List<Payment__c>{
        confirmed(statementId(), 'pi_twice'),
        confirmed(statementId(), 'pi_twice')
      }
    );

    Assert.areEqual(1, result.recorded, 'One recorded');
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
    Payment__c different = confirmed(statementId(), 'pi_existing');
    different.Amount__c = 999.00;

    PaymentRecorder.Recording result = record(
      new List<Payment__c>{ different }
    );

    Assert.areEqual(1, result.alreadyRecorded, 'Seen as recorded already');
    Assert.areEqual(0, result.recorded, 'Nothing new');
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
  static void aRefusedPaymentIsNotedAndTheRestRecorded() {
    Id noSuchStatement = TestIds.missing(Billing_Statement__c.SObjectType);

    PaymentRecorder.Recording result = record(
      new List<Payment__c>{
        confirmed(noSuchStatement, 'pi_orphan'),
        confirmed(statementId(), 'pi_good')
      }
    );
    IntegrationLogger.save();

    Assert.areEqual(1, result.recorded, 'The good one is recorded');
    Assert.areEqual(1, result.refused, 'The other is refused');
    Assert.areEqual(
      1,
      [
        SELECT COUNT()
        FROM Payment__c
        WHERE External_Reference__c = 'pi_good'
        WITH SYSTEM_MODE
      ],
      'On the statement'
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
      'Noted as a payment to record'
    );
    Assert.areEqual('Failed', logged.Outcome__c, 'That failed');
    Assert.areEqual('pi_orphan', logged.Provider_Reference__c, 'Which one');
    Assert.isTrue(
      logged.Details__c.contains(PaymentCheckoutService.SOURCE_PORTAL) &&
      logged.Details__c.contains('reconciliation'),
      'Where it came from, the platform\'s reason and what happens next: ' +
      logged.Details__c
    );
  }

  @IsTest
  static void aDateAfterTodayIsRecordedAsToday() {
    Payment__c tomorrows = confirmed(statementId(), 'pi_tomorrow');
    tomorrows.Payment_Date__c = Date.today().addDays(1);

    record(new List<Payment__c>{ tomorrows });

    Payment__c recorded = [
      SELECT Payment_Date__c
      FROM Payment__c
      WHERE External_Reference__c = 'pi_tomorrow'
      WITH SYSTEM_MODE
    ];
    Assert.areEqual(
      Date.today(),
      recorded.Payment_Date__c,
      'Never in the future, which Accord refuses'
    );
  }

  @IsTest
  static void nothingToRecordSavesNothing() {
    Payment__c noReference = confirmed(statementId(), null);

    Test.startTest();
    PaymentRecorder.Recording result = record(
      new List<Payment__c>{ null, noReference }
    );
    Integer saves = Limits.getDmlStatements();
    Test.stopTest();

    Assert.areEqual(0, result.recorded, 'Nothing recorded');
    Assert.areEqual(0, saves, 'Not even an empty save');
  }
}
