/**
 * ST-05, S-02. Reads a paid Stripe checkout session as the Lease Payment it made: the statement
 * Steward named when it created the session, what Stripe says was paid, the day, and Stripe's
 * payment ID, on which PaymentRecorder records each payment once. Also converts amounts between
 * dollars and the cents Stripe works in.
 */
public with sharing class CheckoutPayments {
  /** Lease Payment Method__c for a payment taken on Stripe's checkout page. */
  public static final String METHOD_CARD = 'Card';

  /**
   * The payment a paid session made, not yet saved.
   * @param session the session, as Stripe describes it
   * @return the payment, or null when the session isn't paid or isn't for a statement
   */
  public static Payment__c toPayment(StripeClient.CheckoutSession session) {
    Id statementId = statementIdOrNull(session?.clientReferenceId);
    if (
      statementId == null ||
      session.paymentStatus != StripeClient.PAID ||
      String.isBlank(session.paymentIntent)
    ) {
      return null;
    }
    return new Payment__c(
      Billing_Statement__c = statementId,
      Amount__c = toDollars(session.amountTotal),
      Payment_Date__c = paidOn(session.created),
      Method__c = METHOD_CARD,
      External_Reference__c = session.paymentIntent
    );
  }

  /**
   * An amount in cents, as dollars.
   * @param cents the amount, in cents
   * @return the amount in dollars, or null
   */
  public static Decimal toDollars(Long cents) {
    return cents == null ? null : Decimal.valueOf(cents).divide(100, 2);
  }

  /**
   * An amount in dollars, as the whole cents Stripe asks for. Half a cent rounds up.
   * @param dollars the amount, in dollars
   * @return the amount in cents, or null
   */
  public static Long toCents(Decimal dollars) {
    return dollars == null
      ? null
      : (dollars.setScale(2, System.RoundingMode.HALF_UP) * 100).longValue();
  }

  /**
   * The statement a session is for, if its client reference is a statement's ID.
   * @param value the session's client reference
   * @return the statement's ID, or null for anything else
   */
  public static Id statementIdOrNull(String value) {
    if (String.isBlank(value)) {
      return null;
    }
    try {
      Id parsed = Id.valueOf(value);
      return parsed.getSObjectType() == Billing_Statement__c.SObjectType
        ? parsed
        : null;
    } catch (StringException notAnId) {
      return null;
    }
  }

  /**
   * The day a session was paid, in the running user's time zone: the day the session was created,
   * which Stripe keeps open for an hour. Never later than today, which Accord's rule requires.
   * @param created seconds since 1970
   * @return the day
   */
  private static Date paidOn(Long created) {
    Date day = created == null
      ? Date.today()
      : Datetime.newInstance(created * 1000).date();
    return day > Date.today() ? Date.today() : day;
  }
}
