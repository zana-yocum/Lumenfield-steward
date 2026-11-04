/**
 * ST-05, ST-12, S-02, NFR-07. Paying a statement online, on Stripe's hosted checkout page. Card
 * details are typed into Stripe's page and never reach Salesforce or the chat.
 *
 * startCheckout makes a checkout session for one of the household's statements, for its balance,
 * and returns the page to send the customer to. confirm asks Stripe whether the session a customer
 * came back from was paid, and if it was, records the payment. reconcile does the same for every
 * completed session Stripe lists, for customers who closed the browser before coming back.
 * PaymentRecorder records each payment once, whichever path saw it first (S-02, S-27).
 */
public with sharing class PaymentCheckoutService {
  /** The statement has no balance to pay. */
  public static final String NOTHING_OWED = 'NOTHING_OWED';
  /** Stripe says the session wasn't paid: the customer went back, or the card was declined. */
  public static final String NOT_PAID = 'NOT_PAID';
  /** Stripe couldn't be reached, or refused. failureDetail has Stripe's error, for the log only. */
  public static final String PROVIDER_UNAVAILABLE = 'PROVIDER_UNAVAILABLE';
  /** Where a payment was confirmed, for the log: the customer came back to the portal. */
  public static final String SOURCE_PORTAL = 'Portal return';
  /** Where a payment was confirmed, for the log: reconciliation found it. */
  public static final String SOURCE_RECONCILIATION = 'Reconciliation';
  /** Stripe's ID for a checkout session starts with this. */
  private static final String SESSION_PREFIX = 'cs_';

  /** The client every call goes through. A test puts a mock behind it with Test.setMock. */
  private static final StripeClient STRIPE = new StripeClient();

  /** Where to send the customer to pay, or why not. */
  public class Checkout extends StewardOutcome.Result {
    /** Stripe's checkout page for this payment. */
    @AuraEnabled
    public String checkoutUrl;
    /** The amount the page asks for: the statement's balance. */
    @AuraEnabled
    public Decimal amount;
    @AuraEnabled
    public String statementNumber;
    /** Stripe's error on a failure. For the log, never for the customer (NFR-07). */
    public String failureDetail;
  }

  /** Whether the session the customer came back from was paid. */
  public class Confirmation extends StewardOutcome.Result {
    @AuraEnabled
    public Id statementId;
    @AuraEnabled
    public String statementNumber;
    /** What Stripe says was paid. */
    @AuraEnabled
    public Decimal amount;
    /**
     * True when the payment is on the statement now. False when the platform refused it for the
     * moment: it's noted for support, and the next reconciliation run records it.
     */
    @AuraEnabled
    public Boolean recorded = false;
    /** Stripe's error on a failure. For the log, never for the customer (NFR-07). */
    public String failureDetail;
  }

  /** What one page of reconciliation found. */
  public class Reconciliation {
    /** Completed sessions Stripe listed. */
    public Integer sessionsRead = 0;
    /** Paid sessions for a statement, recorded now. */
    public Integer paymentsRecorded = 0;
    /** Paid sessions already on a Lease Payment. */
    public Integer paymentsAlreadyRecorded = 0;
    /** Paid sessions the platform refused, each noted for support. */
    public Integer paymentsRefused = 0;
    /** True when Stripe has more sessions after this page. */
    public Boolean hasMore = false;
    /** The last session on this page, where the next page starts. */
    public String lastSessionId;
  }

  /**
   * A checkout session for one of the household's statements, for its balance. A statement that
   * isn't the household's is NOT_FOUND, the same as one that doesn't exist (ST-12).
   * @param household the household paying, already verified by the caller
   * @param statementId the statement; null for the oldest statement with a balance
   * @return the checkout page, or the reason there isn't one
   */
  public static Checkout startCheckout(Id household, Id statementId) {
    Checkout result = new Checkout();
    Billing_Statement__c statement = statementToPay(household, statementId);
    if (statement == null) {
      result.setOutcome(
        StewardOutcome.DECLINED_POLICY,
        StewardOutcome.NOT_FOUND
      );
      return result;
    }
    result.statementNumber = statement.Name;
    result.amount = statement.Balance__c;
    if (statement.Balance__c == null || statement.Balance__c <= 0) {
      result.setOutcome(StewardOutcome.DECLINED_POLICY, NOTHING_OWED);
      return result;
    }
    StripeClient.CheckoutRequest request = new StripeClient.CheckoutRequest();
    request.statementId = statement.Id;
    request.accountId = household;
    request.description =
      'Lumenfield lease payment, statement ' + statement.Name;
    request.amountCents = CheckoutPayments.toCents(statement.Balance__c);
    String page = PortalLinks.statementPage(statement.Id);
    request.successUrl = page + '&c__session_id={CHECKOUT_SESSION_ID}';
    request.cancelUrl = page + '&c__payment=cancelled';
    try {
      result.checkoutUrl = STRIPE.createCheckoutSession(request).url;
      result.setOutcome(StewardOutcome.COMPLETED, null);
    } catch (StripeClient.StripeException stripeError) {
      result.setOutcome(StewardOutcome.FAILED, PROVIDER_UNAVAILABLE);
      result.failureDetail = stripeError.getMessage();
    }
    return result;
  }

  /**
   * Whether the session a customer came back from was paid. A paid session for one of the
   * household's statements is recorded as a Lease Payment, once. A session for anyone else's
   * statement is NOT_FOUND, and nothing is recorded. Stripe is always asked first, so the session
   * ID from the address is never trusted on its own.
   * @param household the household asking, already verified by the caller
   * @param sessionId the session ID Stripe put in the return address
   * @return the confirmation, or the reason there isn't one
   */
  public static Confirmation confirm(Id household, String sessionId) {
    Confirmation result = new Confirmation();
    if (String.isBlank(sessionId) || !sessionId.startsWith(SESSION_PREFIX)) {
      result.setOutcome(
        StewardOutcome.DECLINED_POLICY,
        StewardOutcome.INVALID_REQUEST
      );
      return result;
    }
    StripeClient.CheckoutSession session;
    try {
      session = STRIPE.getCheckoutSession(sessionId, household);
    } catch (StripeClient.StripeException stripeError) {
      result.setOutcome(StewardOutcome.FAILED, PROVIDER_UNAVAILABLE);
      result.failureDetail = stripeError.getMessage();
      return result;
    }
    Billing_Statement__c statement = statementOf(
      household,
      CheckoutPayments.statementIdOrNull(session.clientReferenceId)
    );
    if (statement == null) {
      result.setOutcome(
        StewardOutcome.DECLINED_POLICY,
        StewardOutcome.NOT_FOUND
      );
      return result;
    }
    result.statementId = statement.Id;
    result.statementNumber = statement.Name;
    if (
      session.paymentStatus != StripeClient.PAID ||
      session.paymentIntent == null
    ) {
      result.setOutcome(StewardOutcome.DECLINED_POLICY, NOT_PAID);
      return result;
    }
    result.amount = CheckoutPayments.toDollars(session.amountTotal);
    PaymentRecorder.Recording recording = PaymentRecorder.record(
      new List<Payment__c>{ CheckoutPayments.toPayment(session) },
      SOURCE_PORTAL
    );
    // Stripe has the money either way, so the customer is told it's received. A refusal is noted
    // for support, and the next reconciliation run records it.
    result.recorded = recording.refused == 0;
    result.setOutcome(StewardOutcome.COMPLETED, null);
    return result;
  }

  /**
   * Records every paid session on one page of Stripe's completed sessions. A payment already
   * recorded is skipped, so reading a session twice records it once (S-02). A payment the platform
   * refuses is noted for support and tried again on the next run.
   * @param createdSince seconds since 1970; earlier sessions are left out
   * @param startingAfter the last session of the previous page, or null for the first
   * @return what the page held
   */
  public static Reconciliation reconcile(
    Long createdSince,
    String startingAfter
  ) {
    Reconciliation result = new Reconciliation();
    StripeClient.SessionPage page = STRIPE.listCompletedSessions(
      createdSince,
      startingAfter
    );
    List<Payment__c> payments = new List<Payment__c>();
    for (StripeClient.CheckoutSession session : page.sessions) {
      result.sessionsRead++;
      result.lastSessionId = session.id;
      Payment__c payment = CheckoutPayments.toPayment(session);
      if (payment != null) {
        payments.add(payment);
      }
    }
    PaymentRecorder.Recording recording = PaymentRecorder.record(
      payments,
      SOURCE_RECONCILIATION
    );
    result.paymentsRecorded = recording.recorded;
    result.paymentsAlreadyRecorded = recording.alreadyRecorded;
    result.paymentsRefused = recording.refused;
    result.hasMore = page.hasMore;
    return result;
  }

  private static Billing_Statement__c statementToPay(
    Id household,
    Id statementId
  ) {
    if (statementId != null) {
      return statementOf(household, statementId);
    }
    if (!HouseholdScope.isVisible(household)) {
      return null;
    }
    List<Billing_Statement__c> owing = [
      SELECT Id, Name, Balance__c
      FROM Billing_Statement__c
      WHERE Account__c = :household AND Balance__c > 0
      WITH USER_MODE
      ORDER BY Due_Date__c ASC NULLS LAST, Id
      LIMIT 1
    ];
    return owing.isEmpty() ? null : owing[0];
  }

  /**
   * One of the household's statements, read with the caller's own access.
   * @param household the household
   * @param statementId the statement
   * @return the statement, or null when it isn't the household's or can't be seen
   */
  private static Billing_Statement__c statementOf(
    Id household,
    Id statementId
  ) {
    if (statementId == null || !HouseholdScope.isVisible(household)) {
      return null;
    }
    List<Billing_Statement__c> statements = [
      SELECT Id, Name, Balance__c
      FROM Billing_Statement__c
      WHERE Id = :statementId AND Account__c = :household
      WITH USER_MODE
      LIMIT 1
    ];
    return statements.isEmpty() ? null : statements[0];
  }
}
