/**
 * ST-04, ST-12, GR-03. The self-service rules for a promise to pay, checked in the order the story
 * lists them: hand-offs first (account status, then recent broken promises), then nothing past
 * due, an existing promise, the date window and the minimum amount. The first rule a request
 * breaks is its answer. Households, open promises and Accord's policy values are read once for a
 * whole batch, in user mode; values come from Policy_Setting__mdt through PolicySettings.
 */
public with sharing class ArrangementEligibility {
  // Account statuses where a customer may arrange a date without a person (ST-04). Anything
  // else, including a status added later, hands off.
  private static final Set<String> SELF_SERVICE_STATUSES = new Set<String>{
    'Current',
    'Delinquent'
  };
  private static final Set<String> OPEN_PROMISE_STATUSES = new Set<String>{
    'Active',
    'Pending Approval'
  };
  // Accord's own rule, not a tunable value: its Out_of_Policy__c formula sends any promise for
  // less than the past-due balance for approval, so self-service never accepts less (GR-03).
  private static final Decimal FULL_PAST_DUE_PCT = 100;

  private Map<Id, Account> households = new Map<Id, Account>();
  private Map<Id, Promise_to_Pay__c> openPromises = new Map<Id, Promise_to_Pay__c>();
  private Integer windowDays = PolicySettings.getWholeNumber(
    PolicySettings.PROMISE_WINDOW_DAYS
  );
  private Integer brokenPromiseLimit = PolicySettings.getWholeNumber(
    PolicySettings.SELF_SERVICE_BROKEN_PROMISE_LIMIT
  );
  private Decimal coveragePct = PolicySettings.getNumber(
    PolicySettings.SELF_SERVICE_MIN_COVERAGE_PCT
  );
  private Date today = Date.today();

  /**
   * Reads what the checks need for every request in a batch.
   * @param requests the batch
   */
  public ArrangementEligibility(
    List<PaymentArrangementService.Request> requests
  ) {
    Set<Id> accountIds = new Set<Id>();
    for (PaymentArrangementService.Request request : requests) {
      if (request != null) {
        accountIds.add(request.accountId);
      }
    }
    Set<Id> visible = HouseholdScope.visibleHouseholds(accountIds);
    if (visible.isEmpty()) {
      return;
    }
    households = new Map<Id, Account>(
      [
        SELECT
          Id,
          Account_Status__c,
          Broken_Promises_90d__c,
          Past_Due_Balance__c
        FROM Account
        WHERE Id IN :visible
        WITH USER_MODE
      ]
    );
    for (Promise_to_Pay__c promise : [
      SELECT Id, Account__c, Promise_Amount__c, Promise_Date__c, Status__c
      FROM Promise_to_Pay__c
      WHERE Account__c IN :visible AND Status__c IN :OPEN_PROMISE_STATUSES
      WITH USER_MODE
      ORDER BY Promise_Date__c DESC
    ]) {
      // Sorted latest first, so the earliest open promise is the one left in place.
      openPromises.put(promise.Account__c, promise);
    }
  }

  /**
   * Runs every check for one request, in order. The first that fails is the answer.
   * @param request one request from the batch
   * @return its result: ELIGIBLE, or the rule it breaks with the figures the customer is told
   */
  public PaymentArrangementService.ArrangementResult check(
    PaymentArrangementService.Request request
  ) {
    PaymentArrangementService.ArrangementResult result = new PaymentArrangementService.ArrangementResult();
    if (!isComplete(request)) {
      result.setOutcome(
        StewardOutcome.DECLINED_POLICY,
        StewardOutcome.INVALID_REQUEST
      );
      return result;
    }
    result.promiseDate = request.promiseDate;
    result.promiseAmount = request.amount;
    Account household = households.get(request.accountId);
    if (household == null) {
      result.setOutcome(
        StewardOutcome.DECLINED_POLICY,
        StewardOutcome.NOT_FOUND
      );
      return result;
    }
    // Hand-offs come first and carry no figures, so no collections field is revealed.
    String handoff = handoffReason(household);
    if (handoff != null) {
      result.setOutcome(StewardOutcome.HANDOFF, handoff);
      return result;
    }
    String decline = declineReason(request, household, result);
    if (decline != null) {
      result.setOutcome(StewardOutcome.DECLINED_POLICY, decline);
    } else {
      result.setOutcome(
        StewardOutcome.COMPLETED,
        PaymentArrangementService.ELIGIBLE
      );
    }
    return result;
  }

  /**
   * The least an online arrangement may be for: the policy's share of the past-due balance,
   * never below all of it, rounded up to the cent.
   * @param pastDue the household's past-due balance
   * @param coveragePct Self_Service_Min_Coverage_Pct
   * @return the minimum amount
   */
  @TestVisible
  private static Decimal minimumAmount(Decimal pastDue, Decimal coveragePct) {
    Decimal pct = coveragePct == null
      ? FULL_PAST_DUE_PCT
      : Math.max(coveragePct, FULL_PAST_DUE_PCT);
    return (pastDue * pct / 100).setScale(2, System.RoundingMode.CEILING);
  }

  private Boolean isComplete(PaymentArrangementService.Request request) {
    return request != null &&
      request.accountId != null &&
      request.promiseDate != null &&
      request.amount != null &&
      request.amount > 0;
  }

  private String handoffReason(Account household) {
    if (!SELF_SERVICE_STATUSES.contains(household.Account_Status__c)) {
      return PaymentArrangementService.ACCOUNT_STATUS;
    }
    if (zeroIfNull(household.Broken_Promises_90d__c) >= brokenPromiseLimit) {
      return PaymentArrangementService.BROKEN_PROMISE_LIMIT;
    }
    return null;
  }

  // Fills in the figures the customer is told, and returns the first rule the request breaks.
  private String declineReason(
    PaymentArrangementService.Request request,
    Account household,
    PaymentArrangementService.ArrangementResult result
  ) {
    result.pastDueBalance = zeroIfNull(household.Past_Due_Balance__c);
    if (result.pastDueBalance <= 0) {
      return PaymentArrangementService.NOTHING_PAST_DUE;
    }
    Promise_to_Pay__c existing = openPromises.get(request.accountId);
    if (existing != null) {
      result.existingPromiseAmount = existing.Promise_Amount__c;
      result.existingPromiseDate = existing.Promise_Date__c;
      result.existingPromiseStatus = existing.Status__c;
      return PaymentArrangementService.EXISTING_PROMISE;
    }
    result.latestAllowedDate = today.addDays(windowDays);
    result.minimumAmount = minimumAmount(result.pastDueBalance, coveragePct);
    if (request.promiseDate < today) {
      return PaymentArrangementService.DATE_IN_PAST;
    }
    if (request.promiseDate > result.latestAllowedDate) {
      return PaymentArrangementService.DATE_OUTSIDE_WINDOW;
    }
    return request.amount < result.minimumAmount
      ? PaymentArrangementService.AMOUNT_BELOW_MINIMUM
      : null;
  }

  private static Decimal zeroIfNull(Decimal value) {
    return value == null ? 0 : value;
  }
}
