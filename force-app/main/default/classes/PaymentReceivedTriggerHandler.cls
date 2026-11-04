/**
 * ST-05, S-02, S-27. Records each Payment_Received__e as a Lease Payment (Payment__c), once.
 *
 * The same payment can arrive twice: once when the customer comes back to the portal, and again
 * when reconciliation lists it. Each payment carries Stripe's payment ID, and Accord's
 * External_Reference__c is a unique external ID. So a payment already recorded is skipped, and if
 * two deliveries race, the unique index refuses the second. A payment is never recorded twice,
 * and an existing one is never overwritten.
 *
 * A row the platform rejects is logged on Integration_Log__c for support. A locked row is retried:
 * the platform delivers the batch again, and payments recorded the first time are skipped.
 */
public with sharing class PaymentReceivedTriggerHandler {
  /** How many times a batch is redelivered after a locked row before the rest is logged. */
  @TestVisible
  private static final Integer MAX_RETRIES = 4;
  private static final String OPERATION = 'Record payment';
  private static final String METHOD_CARD = 'Card';

  /**
   * Records the payments in a batch of events.
   * @param events the events, as delivered
   */
  public static void handle(List<Payment_Received__e> events) {
    Map<String, Payment__c> byReference = new Map<String, Payment__c>();
    for (Payment_Received__e event : events) {
      if (
        String.isNotBlank(event.External_Reference__c) &&
        !byReference.containsKey(event.External_Reference__c)
      ) {
        byReference.put(event.External_Reference__c, toPayment(event));
      }
    }
    Elevated elevated = new Elevated();
    List<Payment__c> fresh = elevated.notYetRecorded(byReference);
    if (fresh.isEmpty()) {
      return;
    }
    List<Database.SaveResult> results = elevated.insertPayments(fresh);
    if (isLocked(results) && retries() < MAX_RETRIES) {
      throw new EventBus.RetryableException(
        'A statement was locked; the batch will be delivered again.'
      );
    }
    logRejections(fresh, results);
  }

  private static Payment__c toPayment(Payment_Received__e event) {
    return new Payment__c(
      Billing_Statement__c = event.Statement_Id__c,
      Amount__c = event.Amount__c,
      Payment_Date__c = event.Paid_On__c > Date.today()
        ? Date.today()
        : event.Paid_On__c,
      Method__c = METHOD_CARD,
      External_Reference__c = event.External_Reference__c
    );
  }

  private static Boolean isLocked(List<Database.SaveResult> results) {
    for (Database.SaveResult result : results) {
      for (Database.Error error : result.getErrors()) {
        if (error.getStatusCode() == StatusCode.UNABLE_TO_LOCK_ROW) {
          return true;
        }
      }
    }
    return false;
  }

  private static Integer retries() {
    EventBus.TriggerContext context = EventBus.TriggerContext.currentContext();
    return context == null ? 0 : context.retries;
  }

  /**
   * Logs each payment the platform refused, except a duplicate: that one was recorded already.
   * @param attempted the payments saved
   * @param results their save results, in the same order
   */
  private static void logRejections(
    List<Payment__c> attempted,
    List<Database.SaveResult> results
  ) {
    for (Integer i = 0; i < results.size(); i++) {
      Database.SaveResult result = results[i];
      if (result.isSuccess() || isDuplicate(result)) {
        continue;
      }
      IntegrationLogger.Call call = new IntegrationLogger.Call(
        StripeClient.PROVIDER,
        OPERATION
      );
      call.outcome = IntegrationLogger.FAILED;
      call.statementId = attempted[i].Billing_Statement__c;
      call.providerReference = attempted[i].External_Reference__c;
      call.details = StewardOutcome.describeErrors(result.getErrors());
      IntegrationLogger.record(call);
    }
    IntegrationLogger.save();
  }

  private static Boolean isDuplicate(Database.SaveResult result) {
    for (Database.Error error : result.getErrors()) {
      if (error.getStatusCode() != StatusCode.DUPLICATE_VALUE) {
        return false;
      }
    }
    return true;
  }

  // S-27: the subscriber runs as the Automated Process user, which has no access of its own, so it
  // reads and saves Lease Payments in system mode and without sharing. Every event it handles was
  // published by Steward's own Apex after Stripe said the session was paid; no person can publish
  // one, because no permission set grants create on Payment_Received__e.
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
     * Saves the payments. A row the platform refuses is reported in its result, never thrown.
     * @param payments the payments
     * @return one save result per payment, in order
     */
    public List<Database.SaveResult> insertPayments(List<Payment__c> payments) {
      return Database.insert(payments, false, AccessLevel.SYSTEM_MODE);
    }
  }
}
