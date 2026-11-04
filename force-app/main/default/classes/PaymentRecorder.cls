/**
 * ST-05, S-02, S-27. Records the payments Stripe confirmed as Lease Payments (Payment__c), once.
 * PaymentCheckoutService calls it after Stripe says a session was paid: when the customer comes
 * back to the portal, and when reconciliation lists the session.
 *
 * The same payment can be confirmed twice, once on each path. Each payment carries Stripe's payment
 * ID, and Accord's External_Reference__c is a unique external ID. So a payment already recorded is
 * skipped, and if two confirmations race, the unique index refuses the second. A payment is never
 * recorded twice, and an existing one is never overwritten.
 *
 * A payment the platform refuses, such as one for a locked statement, is noted on
 * Integration_Log__c for support, and the next reconciliation run tries it again. The caller saves
 * the log after its last callout (S-28).
 */
public with sharing class PaymentRecorder {
  private static final String OPERATION = 'Record payment';

  /** What happened to the payments given. */
  public class Recording {
    /** Saved now. */
    public Integer recorded = 0;
    /** On a Lease Payment already, so left as they were. */
    public Integer alreadyRecorded = 0;
    /** Refused by the platform, and noted on the integration log. */
    public Integer refused = 0;
  }

  /**
   * Records each payment whose Stripe payment ID isn't on a Lease Payment yet. A payment without
   * a payment ID is ignored. A date after today is recorded as today, which Accord's rule requires.
   * @param payments the payments Stripe confirmed (CheckoutPayments.toPayment), not yet saved
   * @param source where the confirmation came from, for the log: a return to the portal, or
   * reconciliation
   * @return how many were recorded, were recorded already, and were refused
   */
  public static Recording record(List<Payment__c> payments, String source) {
    Map<String, Payment__c> byReference = byReference(payments);
    if (byReference.isEmpty()) {
      return new Recording();
    }
    Elevated elevated = new Elevated();
    List<Payment__c> fresh = elevated.notYetRecorded(byReference);
    Recording result = fresh.isEmpty()
      ? new Recording()
      : tally(fresh, elevated.insertPayments(fresh), source);
    result.alreadyRecorded += byReference.size() - fresh.size();
    return result;
  }

  /**
   * The payments to record, one per Stripe payment ID, each dated no later than today.
   * @param payments the payments given
   * @return the payments, by Stripe's payment ID
   */
  private static Map<String, Payment__c> byReference(
    List<Payment__c> payments
  ) {
    Map<String, Payment__c> byReference = new Map<String, Payment__c>();
    for (Payment__c payment : payments) {
      if (payment == null || String.isBlank(payment.External_Reference__c)) {
        continue;
      }
      if (payment.Payment_Date__c > Date.today()) {
        payment.Payment_Date__c = Date.today();
      }
      byReference.put(payment.External_Reference__c, payment);
    }
    return byReference;
  }

  /**
   * Counts what the save did, and notes each refusal for support.
   * @param saved the payments saved, in order
   * @param results their save results, in the same order
   * @param source where the confirmation came from
   * @return the counts
   */
  private static Recording tally(
    List<Payment__c> saved,
    List<Database.SaveResult> results,
    String source
  ) {
    Recording result = new Recording();
    for (Integer i = 0; i < results.size(); i++) {
      if (results[i].isSuccess()) {
        result.recorded++;
      } else if (isDuplicate(results[i])) {
        result.alreadyRecorded++;
      } else {
        result.refused++;
        note(saved[i], results[i], source);
      }
    }
    return result;
  }

  /**
   * True when every error is the unique index refusing a payment ID already recorded: another
   * confirmation got there first.
   * @param result the save result
   * @return whether the payment was recorded already
   */
  private static Boolean isDuplicate(Database.SaveResult result) {
    for (Database.Error error : result.getErrors()) {
      if (error.getStatusCode() != StatusCode.DUPLICATE_VALUE) {
        return false;
      }
    }
    return true;
  }

  private static void note(
    Payment__c payment,
    Database.SaveResult result,
    String source
  ) {
    IntegrationLogger.Call call = new IntegrationLogger.Call(
      StripeClient.PROVIDER,
      OPERATION
    );
    call.outcome = IntegrationLogger.FAILED;
    call.statementId = payment.Billing_Statement__c;
    call.providerReference = payment.External_Reference__c;
    call.details =
      source +
      ': ' +
      StewardOutcome.describeErrors(result.getErrors()) +
      ' The next reconciliation run tries again.';
    IntegrationLogger.record(call);
  }

  // S-27: payments are read and saved in system mode and without sharing. The customer coming back
  // to the portal and the agent can only read Lease Payments, and nobody gets create on them from
  // Steward. Every payment saved here was read back from Stripe as paid, for a statement the
  // caller's household owns or, in reconciliation, for the statement Steward named when it
  // created the session.
  private without sharing class Elevated {
    /**
     * The payments whose Stripe payment ID isn't on a Lease Payment yet.
     * @param byReference the payments, by Stripe's payment ID
     * @return the payments still to record
     */
    public List<Payment__c> notYetRecorded(
      Map<String, Payment__c> byReference
    ) {
      Map<String, Payment__c> fresh = new Map<String, Payment__c>(byReference);
      Set<String> references = new Set<String>(byReference.keySet());
      for (Payment__c existing : [
        SELECT External_Reference__c
        FROM Payment__c
        WHERE External_Reference__c IN :references
        WITH SYSTEM_MODE
      ]) {
        fresh.remove(existing.External_Reference__c);
      }
      return fresh.values();
    }

    /**
     * Saves the payments. A payment the platform refuses is reported in its result, never thrown.
     * @param payments the payments
     * @return one save result per payment, in order
     */
    public List<Database.SaveResult> insertPayments(List<Payment__c> payments) {
      return Database.insert(payments, false, AccessLevel.SYSTEM_MODE);
    }
  }
}
