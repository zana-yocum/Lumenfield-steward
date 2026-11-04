/**
 * ST-05, S-02. Proves amounts convert between dollars and Stripe's cents without losing a cent,
 * and that a client reference is taken as a statement only when it is a statement's ID.
 */
@IsTest
private class PaymentEventsTest {
  @IsTest
  static void dollarsAndCentsConvertBothWays() {
    Assert.areEqual(12000L, PaymentEvents.toCents(120.00), 'Whole dollars');
    Assert.areEqual(9550L, PaymentEvents.toCents(95.5), 'Dollars and cents');
    Assert.areEqual(
      1001L,
      PaymentEvents.toCents(10.005),
      'Half a cent rounds up'
    );
    Assert.areEqual(120.00, PaymentEvents.toDollars(12000L), 'Back again');
    Assert.areEqual(0.07, PaymentEvents.toDollars(7L), 'Cents alone');
    Assert.isNull(PaymentEvents.toCents(null), 'Nothing stays nothing');
    Assert.isNull(PaymentEvents.toDollars(null), 'Either way');
  }

  @IsTest
  static void onlyAStatementsIdIsTakenAsAStatement() {
    Id statement = TestIds.missing(Billing_Statement__c.SObjectType);

    Assert.areEqual(
      statement,
      PaymentEvents.statementIdOrNull(String.valueOf(statement)),
      'A statement\'s ID'
    );
    Assert.isNull(
      PaymentEvents.statementIdOrNull(
        String.valueOf(TestIds.missing(Account.SObjectType))
      ),
      'An account\'s ID is not a statement'
    );
    Assert.isNull(
      PaymentEvents.statementIdOrNull('order-1234'),
      'Nor is anything else'
    );
    Assert.isNull(PaymentEvents.statementIdOrNull(' '), 'Nor a blank');
  }
}
