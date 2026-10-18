/**
 * ST-04, ST-12, GR-02, GR-03. Checks whether a household can set up a promise to pay on its own,
 * and creates one when policy allows. The checks exist to give the customer a clear answer first
 * (S-03); the save still goes through Accord's flow and rules, which read the same policy records.
 * If Accord's flow ever sends a new promise for approval anyway, the service rolls the save back,
 * so the agent never leaves behind anything a supervisor would have to approve (GR-03).
 */
public with sharing class PaymentArrangementService {
  /** Every check passed. */
  public static final String ELIGIBLE = 'ELIGIBLE';
  /** Default Review, Hardship Review or Closed: a person handles these. */
  public static final String ACCOUNT_STATUS = 'ACCOUNT_STATUS';
  /** Too many broken promises in the last 90 days for self-service. */
  public static final String BROKEN_PROMISE_LIMIT = 'BROKEN_PROMISE_LIMIT';
  /** Nothing is past due, so there's nothing to arrange. */
  public static final String NOTHING_PAST_DUE = 'NOTHING_PAST_DUE';
  /** An Active or Pending Approval promise already exists. */
  public static final String EXISTING_PROMISE = 'EXISTING_PROMISE';
  /** The promise date is before today. */
  public static final String DATE_IN_PAST = 'DATE_IN_PAST';
  /** The promise date is past the window. latestAllowedDate says how far out is allowed. */
  public static final String DATE_OUTSIDE_WINDOW = 'DATE_OUTSIDE_WINDOW';
  /** The amount is less than the minimum. minimumAmount says what it is. */
  public static final String AMOUNT_BELOW_MINIMUM = 'AMOUNT_BELOW_MINIMUM';
  /** Accord's flow would have sent the promise for approval, so it was rolled back. */
  public static final String WOULD_NEED_APPROVAL = 'WOULD_NEED_APPROVAL';
  /** The save failed. failureDetail has the platform's message, for the log only. */
  public static final String SAVE_FAILED = 'SAVE_FAILED';

  private static final String PROMISE_ACTIVE = 'Active';

  /** One arrangement to check or create. */
  public class Request {
    /** The verified household (S-07). */
    public Id accountId;
    /** The date the customer will pay. */
    public Date promiseDate;
    /** What the customer will pay. */
    public Decimal amount;

    /**
     * An arrangement for one household.
     * @param accountId the verified household
     * @param promiseDate the date the customer will pay
     * @param amount what the customer will pay
     */
    public Request(Id accountId, Date promiseDate, Decimal amount) {
      this.accountId = accountId;
      this.promiseDate = promiseDate;
      this.amount = amount;
    }
  }

  /** The answer for one request. Only the fields that apply to its reason are filled in. */
  public class ArrangementResult extends StewardOutcome.Result {
    @AuraEnabled
    public Decimal pastDueBalance;
    /** The least an online arrangement may be for. */
    @AuraEnabled
    public Decimal minimumAmount;
    /** The latest date an online arrangement may be for. */
    @AuraEnabled
    public Date latestAllowedDate;
    @AuraEnabled
    public Date promiseDate;
    @AuraEnabled
    public Decimal promiseAmount;
    @AuraEnabled
    public Id promiseId;
    @AuraEnabled
    public String promiseNumber;
    @AuraEnabled
    public String promiseStatus;
    /** Accord's Grace_Ends__c, which its flow copies to the account's Collection Hold Until. */
    @AuraEnabled
    public Date holdUntil;
    @AuraEnabled
    public Decimal existingPromiseAmount;
    @AuraEnabled
    public Date existingPromiseDate;
    @AuraEnabled
    public String existingPromiseStatus;
    /** The platform's error for a failed save. For the log, never for the customer (NFR-07). */
    public String failureDetail;
  }

  /**
   * Checks requests against the policy without saving anything.
   * @param requests the arrangements to check
   * @return one result per request, in order; ELIGIBLE when every check passes
   */
  public static List<ArrangementResult> checkEligibility(
    List<Request> requests
  ) {
    return evaluate(requests);
  }

  /**
   * Checks requests and creates an Active promise to pay for each eligible one. Accord's flow
   * then sets the account's Collection Hold Until date.
   * @param requests the arrangements the customer confirmed (GR-05)
   * @return one result per request, in order; COMPLETED with the new promise when saved
   */
  public static List<ArrangementResult> createArrangements(
    List<Request> requests
  ) {
    List<ArrangementResult> results = evaluate(requests);
    List<Integer> toSave = onePerHousehold(requests, results);
    if (toSave.isEmpty()) {
      return results;
    }
    Savepoint beforeSave = Database.setSavepoint();
    SavePass firstPass = saveAndConfirm(requests, results, toSave);
    if (firstPass.needsApproval.isEmpty()) {
      return results;
    }
    // Accord's flow sent at least one promise for approval. Undo the whole save, then save again
    // only the promises that stayed Active, so nothing that needs approval is left behind.
    Database.rollback(beforeSave);
    if (!firstPass.active.isEmpty()) {
      Savepoint beforeRetry = Database.setSavepoint();
      SavePass retry = saveAndConfirm(requests, results, firstPass.active);
      if (!retry.needsApproval.isEmpty()) {
        Database.rollback(beforeRetry);
        markFailed(results, firstPass.active);
      }
    }
    return results;
  }

  private static List<ArrangementResult> evaluate(List<Request> requests) {
    List<ArrangementResult> results = new List<ArrangementResult>();
    if (requests == null || requests.isEmpty()) {
      return results;
    }
    ArrangementEligibility eligibility = new ArrangementEligibility(requests);
    for (Request request : requests) {
      results.add(eligibility.check(request));
    }
    return results;
  }

  // The eligible requests to save, at most one per household: a second request for the same
  // household in the batch is declined, because Accord allows one active promise.
  private static List<Integer> onePerHousehold(
    List<Request> requests,
    List<ArrangementResult> results
  ) {
    List<Integer> toSave = new List<Integer>();
    Map<Id, Request> firstByAccount = new Map<Id, Request>();
    for (Integer i = 0; i < results.size(); i++) {
      if (results[i].reasonCode != ELIGIBLE) {
        continue;
      }
      Request firstRequest = firstByAccount.get(requests[i].accountId);
      if (firstRequest == null) {
        firstByAccount.put(requests[i].accountId, requests[i]);
        toSave.add(i);
      } else {
        results[i].existingPromiseAmount = firstRequest.amount;
        results[i].existingPromiseDate = firstRequest.promiseDate;
        results[i].existingPromiseStatus = PROMISE_ACTIVE;
        results[i].setOutcome(StewardOutcome.DECLINED_POLICY, EXISTING_PROMISE);
      }
    }
    return toSave;
  }

  private static SavePass saveAndConfirm(
    List<Request> requests,
    List<ArrangementResult> results,
    List<Integer> indexes
  ) {
    List<Promise_to_Pay__c> promises = new List<Promise_to_Pay__c>();
    for (Integer i : indexes) {
      promises.add(
        new Promise_to_Pay__c(
          Account__c = requests[i].accountId,
          Promise_Date__c = requests[i].promiseDate,
          Promise_Amount__c = requests[i].amount,
          Status__c = PROMISE_ACTIVE
        )
      );
    }
    List<Database.SaveResult> saves = Database.insert(
      promises,
      false,
      AccessLevel.USER_MODE
    );
    Map<Id, Integer> indexByPromiseId = new Map<Id, Integer>();
    for (Integer k = 0; k < saves.size(); k++) {
      if (saves[k].isSuccess()) {
        indexByPromiseId.put(saves[k].getId(), indexes[k]);
      } else {
        ArrangementResult result = results[indexes[k]];
        result.setOutcome(StewardOutcome.FAILED, SAVE_FAILED);
        result.failureDetail = StewardOutcome.describeErrors(
          saves[k].getErrors()
        );
        clearSavedPromise(result);
      }
    }
    return confirmStatuses(indexByPromiseId, results);
  }

  // Reads back what Accord's flow did to each new promise.
  private static SavePass confirmStatuses(
    Map<Id, Integer> indexByPromiseId,
    List<ArrangementResult> results
  ) {
    SavePass pass = new SavePass();
    if (indexByPromiseId.isEmpty()) {
      return pass;
    }
    for (Promise_to_Pay__c saved : [
      SELECT Id, Name, Status__c, Grace_Ends__c
      FROM Promise_to_Pay__c
      WHERE Id IN :indexByPromiseId.keySet()
      WITH USER_MODE
    ]) {
      Integer i = indexByPromiseId.get(saved.Id);
      ArrangementResult result = results[i];
      if (saved.Status__c == PROMISE_ACTIVE) {
        pass.active.add(i);
        result.promiseId = saved.Id;
        result.promiseNumber = saved.Name;
        result.promiseStatus = saved.Status__c;
        result.holdUntil = saved.Grace_Ends__c;
        result.setOutcome(StewardOutcome.COMPLETED, null);
      } else {
        pass.needsApproval.add(i);
        clearSavedPromise(result);
        result.setOutcome(StewardOutcome.DECLINED_POLICY, WOULD_NEED_APPROVAL);
      }
    }
    return pass;
  }

  private static void markFailed(
    List<ArrangementResult> results,
    List<Integer> indexes
  ) {
    for (Integer i : indexes) {
      results[i].setOutcome(StewardOutcome.FAILED, SAVE_FAILED);
      results[i].failureDetail = 'Promise status changed after the retry.';
      clearSavedPromise(results[i]);
    }
  }

  private static void clearSavedPromise(ArrangementResult result) {
    result.promiseId = null;
    result.promiseNumber = null;
    result.promiseStatus = null;
    result.holdUntil = null;
  }

  // Which promises in one save stayed Active and which Accord's flow sent for approval.
  private class SavePass {
    public List<Integer> active = new List<Integer>();
    public List<Integer> needsApproval = new List<Integer>();
  }
}
