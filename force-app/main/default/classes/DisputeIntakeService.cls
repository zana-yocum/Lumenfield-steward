/**
 * ST-06, ST-12, GR-02. Opens a Billing Dispute case on a statement in the household and returns
 * the case number with the evidence to send for the reason, required items first. Accord takes
 * over from the save: its flows stamp the SLA entitlement and flag the statement as disputed, and
 * its assignment rule routes the case to Dispute Specialists. The rule is asked for explicitly,
 * because assignment rules don't run on cases Apex creates unless told to.
 */
public with sharing class DisputeIntakeService {
  /** The reason isn't one of the eight dispute reasons. */
  public static final String INVALID_REASON = 'INVALID_REASON';
  /** No statement was named. A dispute has to be about a statement. */
  public static final String STATEMENT_REQUIRED = 'STATEMENT_REQUIRED';
  /** The statement already has an open dispute. caseNumber points to it. */
  public static final String EXISTING_DISPUTE = 'EXISTING_DISPUTE';
  /** The caller can't create cases or set one of the dispute's fields. */
  public static final String ACCESS_DENIED = 'ACCESS_DENIED';
  /** The save failed. failureDetail has the platform's message, for the log only. */
  public static final String SAVE_FAILED = 'SAVE_FAILED';

  private static final String DISPUTE_RECORD_TYPE = 'Billing_Dispute';
  private static final String ORIGIN_WEB = 'Web';
  private static final String SUBJECT_PREFIX = 'Billing dispute: ';
  private static final String ACCOUNT_FIELD = 'AccountId';

  /** One dispute to open. */
  public class Request {
    /** The verified household (S-07). */
    public Id accountId;
    /** The statement being disputed. */
    public Id statementId;
    /** One of the Dispute_Reason__c values. */
    public String reason;
    /** The customer's own words, optional. Card numbers are removed before saving. */
    public String description;

    /**
     * A dispute on one statement.
     * @param accountId the verified household
     * @param statementId the statement being disputed
     * @param reason one of the Dispute_Reason__c values
     */
    public Request(Id accountId, Id statementId, String reason) {
      this.accountId = accountId;
      this.statementId = statementId;
      this.reason = reason;
    }
  }

  /** The answer for one request. */
  public class DisputeResult extends StewardOutcome.Result {
    @AuraEnabled
    public Id caseId;
    @AuraEnabled
    public String caseNumber;
    @AuraEnabled
    public String caseStatus;
    @AuraEnabled
    public String reason;
    /** What the customer needs to send, required items first. */
    @AuraEnabled
    public List<DisputeEvidenceCatalog.EvidenceItem> evidence = new List<DisputeEvidenceCatalog.EvidenceItem>();
    /** The platform's error for a failed save. For the log, never for the customer (NFR-07). */
    public String failureDetail;
  }

  /**
   * Opens one dispute.
   * @param request the dispute the customer confirmed (GR-05)
   * @return the result
   */
  public static DisputeResult openDispute(Request request) {
    return openDisputes(new List<Request>{ request })[0];
  }

  /**
   * Opens disputes for the requests that pass every check, in one save.
   * @param requests the disputes the customer confirmed (GR-05)
   * @return one result per request, in order; COMPLETED with the case number when saved
   */
  public static List<DisputeResult> openDisputes(List<Request> requests) {
    List<DisputeResult> results = new List<DisputeResult>();
    if (requests == null || requests.isEmpty()) {
      return results;
    }
    Intake intake = new Intake(requests);
    List<Case> disputes = new List<Case>();
    List<Integer> indexes = new List<Integer>();
    for (Integer i = 0; i < requests.size(); i++) {
      DisputeResult result = new DisputeResult();
      results.add(result);
      Case dispute = intake.disputeFor(requests[i], result);
      if (dispute != null) {
        disputes.add(dispute);
        indexes.add(i);
      }
    }
    if (!disputes.isEmpty()) {
      saveDisputes(disputes, indexes, results);
    }
    return results;
  }

  /**
   * Applies the caller's own create access to the dispute: the Case object and every field set
   * on it, except Case.AccountId, which no profile or permission set can edit (S-14).
   * @param disputes the cases about to be saved
   * @return null when the caller may create them, otherwise what's blocked
   */
  @TestVisible
  private static String blockedFields(List<Case> disputes) {
    if (!Schema.SObjectType.Case.isCreateable()) {
      return 'Case';
    }
    SObjectAccessDecision decision = Security.stripInaccessible(
      AccessType.CREATABLE,
      disputes
    );
    Set<String> removed = new Set<String>();
    Map<String, Set<String>> removedByType = decision.getRemovedFields();
    if (removedByType.containsKey('Case')) {
      removed.addAll(removedByType.get('Case'));
    }
    removed.remove(ACCOUNT_FIELD);
    if (removed.isEmpty()) {
      return null;
    }
    List<String> names = new List<String>(removed);
    names.sort();
    return String.join(names, ', ');
  }

  private static void saveDisputes(
    List<Case> disputes,
    List<Integer> indexes,
    List<DisputeResult> results
  ) {
    String blocked = blockedFields(disputes);
    if (blocked != null) {
      for (Integer i : indexes) {
        results[i].setOutcome(StewardOutcome.FAILED, ACCESS_DENIED);
        results[i].failureDetail = 'No create access to: ' + blocked;
      }
      return;
    }
    Database.DMLOptions options = new Database.DMLOptions();
    options.assignmentRuleHeader.useDefaultRule = true;
    for (Case dispute : disputes) {
      dispute.setOptions(options);
    }
    // S-14: saved in system mode only because Case.AccountId is read-only to every profile and
    // permission set, and Accord's entitlement flow needs the account at the moment of creation.
    // blockedFields has already applied the caller's own create access to every other field.
    List<Database.SaveResult> saves = Database.insert(
      disputes,
      false,
      AccessLevel.SYSTEM_MODE
    );
    Map<Id, DisputeResult> savedById = new Map<Id, DisputeResult>();
    for (Integer k = 0; k < saves.size(); k++) {
      DisputeResult result = results[indexes[k]];
      if (saves[k].isSuccess()) {
        result.caseId = saves[k].getId();
        result.evidence = DisputeEvidenceCatalog.evidenceFor(result.reason);
        result.setOutcome(StewardOutcome.COMPLETED, null);
        savedById.put(result.caseId, result);
      } else {
        result.setOutcome(StewardOutcome.FAILED, SAVE_FAILED);
        result.failureDetail = StewardOutcome.describeErrors(
          saves[k].getErrors()
        );
      }
    }
    readBackCaseNumbers(savedById);
  }

  // Read back in user mode. Once the case is in the Dispute Specialists queue, the caller needs
  // read access through sharing to see its number (set up for the agent user in Phase 6).
  private static void readBackCaseNumbers(Map<Id, DisputeResult> savedById) {
    if (savedById.isEmpty()) {
      return;
    }
    for (Case saved : [
      SELECT Id, CaseNumber, Status
      FROM Case
      WHERE Id IN :savedById.keySet()
      WITH USER_MODE
    ]) {
      DisputeResult result = savedById.get(saved.Id);
      result.caseNumber = saved.CaseNumber;
      result.caseStatus = saved.Status;
    }
  }

  private static String fitDescription(String description) {
    if (description == null) {
      return null;
    }
    Integer maxLength = Case.Description.getDescribe().getLength();
    return description.length() > maxLength
      ? description.left(maxLength)
      : description;
  }

  // Everything the checks need, read once for the whole batch, in user mode.
  private with sharing class Intake {
    private Set<Id> visible;
    private Map<Id, Account> households = new Map<Id, Account>();
    private Map<Id, Billing_Statement__c> statements = new Map<Id, Billing_Statement__c>();
    private Map<Id, Case> openDisputes = new Map<Id, Case>();
    private Set<Id> claimed = new Set<Id>();
    private Id recordTypeId;

    /**
     * Reads what the checks need for every request in the batch.
     * @param requests the batch
     */
    public Intake(List<Request> requests) {
      Set<Id> accountIds = new Set<Id>();
      Set<Id> statementIds = new Set<Id>();
      for (Request request : requests) {
        if (request != null) {
          accountIds.add(request.accountId);
          statementIds.add(request.statementId);
        }
      }
      statementIds.remove(null);
      visible = HouseholdScope.visibleHouseholds(accountIds);
      if (visible.isEmpty()) {
        return;
      }
      households = new Map<Id, Account>(
        [
          SELECT Id, Primary_Contact__c
          FROM Account
          WHERE Id IN :visible
          WITH USER_MODE
        ]
      );
      statements = new Map<Id, Billing_Statement__c>(
        [
          SELECT Id, Account__c, Service_Contract__c, Dispute_Open__c
          FROM Billing_Statement__c
          WHERE Id IN :statementIds AND Account__c IN :visible
          WITH USER_MODE
        ]
      );
      loadOpenDisputes();
    }

    private void loadOpenDisputes() {
      if (statements.isEmpty()) {
        return;
      }
      for (Case existing : [
        SELECT Id, CaseNumber, Status, Disputed_Statement__c
        FROM Case
        WHERE
          Disputed_Statement__c IN :statements.keySet()
          AND RecordType.DeveloperName = :DISPUTE_RECORD_TYPE
          AND IsClosed = FALSE
        WITH USER_MODE
        ORDER BY CreatedDate ASC
      ]) {
        if (!openDisputes.containsKey(existing.Disputed_Statement__c)) {
          openDisputes.put(existing.Disputed_Statement__c, existing);
        }
      }
    }

    /**
     * The case to save for a request.
     * @param request one request from the batch
     * @param result its result, which says why when no case comes back
     * @return the case to save, or null when a check failed
     */
    public Case disputeFor(Request request, DisputeResult result) {
      result.reason = request?.reason;
      String problem = firstProblem(request);
      if (problem != null) {
        result.setOutcome(StewardOutcome.DECLINED_POLICY, problem);
        return null;
      }
      Billing_Statement__c statement = statements.get(request.statementId);
      if (isAlreadyDisputed(statement, result)) {
        return null;
      }
      claimed.add(statement.Id);
      if (recordTypeId == null) {
        recordTypeId = Schema.SObjectType.Case.getRecordTypeInfosByDeveloperName()
          .get(DISPUTE_RECORD_TYPE)
          .getRecordTypeId();
      }
      Case dispute = new Case(
        RecordTypeId = recordTypeId,
        AccountId = request.accountId,
        ContactId = households.get(request.accountId).Primary_Contact__c,
        Disputed_Statement__c = statement.Id,
        Service_Contract__c = statement.Service_Contract__c,
        Dispute_Reason__c = request.reason,
        Origin = ORIGIN_WEB,
        Subject = SUBJECT_PREFIX + request.reason
      );
      dispute.Description = fitDescription(
        SensitiveText.redact(request.description)
      );
      return dispute;
    }

    // The checks run in this order, and the first one that fails is the answer.
    private String firstProblem(Request request) {
      if (request == null || request.accountId == null) {
        return StewardOutcome.INVALID_REQUEST;
      }
      if (!visible.contains(request.accountId)) {
        return StewardOutcome.NOT_FOUND;
      }
      if (request.statementId == null) {
        return STATEMENT_REQUIRED;
      }
      Billing_Statement__c statement = statements.get(request.statementId);
      if (statement == null || statement.Account__c != request.accountId) {
        // Another household's statement looks exactly like one that doesn't exist (ST-12).
        return StewardOutcome.NOT_FOUND;
      }
      return DisputeEvidenceCatalog.isReason(request.reason)
        ? null
        : INVALID_REASON;
    }

    private Boolean isAlreadyDisputed(
      Billing_Statement__c statement,
      DisputeResult result
    ) {
      Case existing = openDisputes.get(statement.Id);
      if (
        existing == null &&
        !statement.Dispute_Open__c &&
        !claimed.contains(statement.Id)
      ) {
        return false;
      }
      result.setOutcome(StewardOutcome.DECLINED_POLICY, EXISTING_DISPUTE);
      if (existing != null) {
        result.caseId = existing.Id;
        result.caseNumber = existing.CaseNumber;
        result.caseStatus = existing.Status;
      }
      return true;
    }
  }
}
