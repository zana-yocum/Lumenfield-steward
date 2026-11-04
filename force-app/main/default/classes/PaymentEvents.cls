/**
 * ST-05, S-02. Turns a paid Stripe checkout session into a Payment_Received__e and publishes it,
 * for PaymentCheckoutService. The event carries the statement Steward named when it created the
 * session, what Stripe says was paid, the day, and Stripe's payment ID, on which the subscriber
 * records each payment once.
 */
public with sharing class PaymentEvents {
  /**
   * The event for a paid session.
   * @param session the session, as Stripe describes it
   * @param source where the confirmation came from, such as Portal return
   * @return the event, not yet published
   */
  public static Payment_Received__e forSession(
    StripeClient.CheckoutSession session,
    String source
  ) {
    return new Payment_Received__e(
      Statement_Id__c = session.clientReferenceId,
      Amount__c = toDollars(session.amountTotal),
      Paid_On__c = paidOn(session.created),
      External_Reference__c = session.paymentIntent,
      Source__c = source
    );
  }

  /**
   * Publishes payment events. They go out once the transaction commits.
   * @param events the events
   * @return the platform's errors as one line, or null when every event was published
   */
  public static String publish(List<Payment_Received__e> events) {
    if (events.isEmpty()) {
      return null;
    }
    List<String> failures = new List<String>();
    for (Database.SaveResult published : EventBus.publish(events)) {
      if (!published.isSuccess()) {
        failures.add(StewardOutcome.describeErrors(published.getErrors()));
      }
    }
    return failures.isEmpty() ? null : String.join(failures, '; ');
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
