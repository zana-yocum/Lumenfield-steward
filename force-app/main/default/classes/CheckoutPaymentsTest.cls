/**
 * ST-05, S-02. Proves a paid session reads as the Lease Payment it made, and anything else as no
 * payment at all; that amounts convert between dollars and Stripe's cents without losing a cent;
 * and that a client reference is taken as a statement only when it is a statement's ID.
 */
@IsTest
private class CheckoutPaymentsTest {
  // A $55.00 session for a statement that needn't exist: nothing here is saved.
  private static StripeClient.CheckoutSession paidSession(Id statementId) {
    StripeClient.CheckoutSession session = new StripeClient.CheckoutSession();
    session.id = 'cs_test_1';
    session.clientReferenceId = statementId;
    session.paymentStatus = StripeClient.PAID;
    session.paymentIntent = 'pi_test_1';
    session.amountTotal = 5500;
    session.created = Datetime.now().addDays(-1).getTime() / 1000;
    return session;
  }

  @IsTest
  static void aPaidSessionIsThePaymentItMade() {
    Id statement = TestIds.missing(Billing_Statement__c.SObjectType);

    Payment__c payment = CheckoutPayments.toPayment(paidSession(statement));

    Assert.areEqual(statement, payment.Billing_Statement__c, 'Its statement');
    Assert.areEqual(55.00, payment.Amount__c, 'In dollars');
    Assert.areEqual(
      Date.today().addDays(-1),
      payment.Payment_Date__c,
      'The day it was paid'
    );
    Assert.areEqual('Card', payment.Method__c, 'By card');
    Assert.areEqual(
      'pi_test_1',
      payment.External_Reference__c,
      'Stripe\'s payment ID, on which it is recorded once'
    );
  }

  @IsTest
  static void anythingElseIsNoPayment() {
    Id statement = TestIds.missing(Billing_Statement__c.SObjectType);
    StripeClient.CheckoutSession unpaid = paidSession(statement);
    unpaid.paymentStatus = 'unpaid';
    StripeClient.CheckoutSession noPaymentId = paidSession(statement);
    noPaymentId.paymentIntent = null;
    StripeClient.CheckoutSession notAStatement = paidSession(
      TestIds.missing(Account.SObjectType)
    );

    Assert.isNull(CheckoutPayments.toPayment(unpaid), 'Not paid');
    Assert.isNull(CheckoutPayments.toPayment(noPaymentId), 'No payment ID');
    Assert.isNull(
      CheckoutPayments.toPayment(notAStatement),
      'Not for a statement'
    );
    Assert.isNull(CheckoutPayments.toPayment(null), 'No session');
  }

  @IsTest
  static void aSessionDatedAfterTodayIsPaidToday() {
    StripeClient.CheckoutSession tomorrows = paidSession(
      TestIds.missing(Billing_Statement__c.SObjectType)
    );
    tomorrows.created = Datetime.now().addDays(2).getTime() / 1000;

    Assert.areEqual(
      Date.today(),
      CheckoutPayments.toPayment(tomorrows).Payment_Date__c,
      'Never in the future, which Accord refuses'
    );
  }

  @IsTest
  static void dollarsAndCentsConvertBothWays() {
    Assert.areEqual(12000L, CheckoutPayments.toCents(120.00), 'Whole dollars');
    Assert.areEqual(9550L, CheckoutPayments.toCents(95.5), 'Dollars and cents');
    Assert.areEqual(
      1001L,
      CheckoutPayments.toCents(10.005),
      'Half a cent rounds up'
    );
    Assert.areEqual(120.00, CheckoutPayments.toDollars(12000L), 'Back again');
    Assert.areEqual(0.07, CheckoutPayments.toDollars(7L), 'Cents alone');
    Assert.isNull(CheckoutPayments.toCents(null), 'Nothing stays nothing');
    Assert.isNull(CheckoutPayments.toDollars(null), 'Either way');
  }

  @IsTest
  static void onlyAStatementsIdIsTakenAsAStatement() {
    Id statement = TestIds.missing(Billing_Statement__c.SObjectType);

    Assert.areEqual(
      statement,
      CheckoutPayments.statementIdOrNull(String.valueOf(statement)),
      'A statement\'s ID'
    );
    Assert.isNull(
      CheckoutPayments.statementIdOrNull(
        String.valueOf(TestIds.missing(Account.SObjectType))
      ),
      'An account\'s ID is not a statement'
    );
    Assert.isNull(
      CheckoutPayments.statementIdOrNull('order-1234'),
      'Nor is anything else'
    );
    Assert.isNull(CheckoutPayments.statementIdOrNull(' '), 'Nor a blank');
  }
}
