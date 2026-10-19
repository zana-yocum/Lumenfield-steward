/**
 * ST-06, ST-12, S-16. A household's billing disputes, for the portal now and the agent in Phase 6:
 * each one's case number, status, reason, the statement it's about and when it was opened, and
 * for a single dispute, the evidence its reason calls for, required items first. Never the root
 * cause, the resolution notes or anything about the sales team. Checks the household first and
 * reads in user mode, so for a customer, sharing decides which disputes come back.
 */
public with sharing class DisputeStatusService {
  private static final String DISPUTE_RECORD_TYPE = 'Billing_Dispute';

  /** One dispute, as the customer may see it. */
  public class DisputeView {
    @AuraEnabled
    public Id caseId;
    @AuraEnabled
    public String caseNumber;
    @AuraEnabled
    public String status;
    @AuraEnabled
    public Boolean isClosed;
    @AuraEnabled
    public String reason;
    @AuraEnabled
    public Id statementId;
    @AuraEnabled
    public String statementNumber;
    @AuraEnabled
    public Date openedDate;
  }

  /** A household's disputes, newest first. */
  public class HouseholdDisputes extends StewardOutcome.Result {
    @AuraEnabled
    public Id accountId;
    @AuraEnabled
    public List<DisputeView> disputes = new List<DisputeView>();
  }

  /** One dispute with the evidence its reason calls for. */
  public class DisputeDetail extends StewardOutcome.Result {
    @AuraEnabled
    public DisputeView dispute;
    @AuraEnabled
    public List<DisputeEvidenceCatalog.EvidenceItem> evidence = new List<DisputeEvidenceCatalog.EvidenceItem>();
  }

  /**
   * One household's disputes.
   * @param accountId the verified household
   * @return its disputes; NOT_FOUND when the caller can't see it
   */
  public static HouseholdDisputes forHousehold(Id accountId) {
    return forHouseholds(new Set<Id>{ accountId }).get(accountId);
  }

  /**
   * Disputes for many households, with one query however many there are.
   * @param accountIds the households to read
   * @return one result per requested ID, keyed by that ID
   */
  public static Map<Id, HouseholdDisputes> forHouseholds(Set<Id> accountIds) {
    Map<Id, HouseholdDisputes> results = new Map<Id, HouseholdDisputes>();
    if (accountIds == null) {
      return results;
    }
    Set<Id> visible = HouseholdScope.visibleHouseholds(accountIds);
    for (Id accountId : accountIds) {
      HouseholdDisputes result = new HouseholdDisputes();
      result.accountId = accountId;
      setScopeOutcome(result, accountId, visible);
      results.put(accountId, result);
    }
    if (visible.isEmpty()) {
      return results;
    }
    for (Case dispute : [
      SELECT
        Id,
        AccountId,
        CaseNumber,
        Status,
        IsClosed,
        Dispute_Reason__c,
        Disputed_Statement__c,
        Disputed_Statement__r.Name,
        CreatedDate
      FROM Case
      WHERE
        AccountId IN :visible
        AND RecordType.DeveloperName = :DISPUTE_RECORD_TYPE
      WITH USER_MODE
      ORDER BY CreatedDate DESC, CaseNumber DESC
    ]) {
      results.get(dispute.AccountId).disputes.add(toView(dispute));
    }
    return results;
  }

  /**
   * One dispute in the household, with its evidence list.
   * @param accountId the verified household
   * @param caseId the dispute asked for
   * @return the dispute; NOT_FOUND when it isn't one of the household's disputes or the caller
   *   can't see it, the same answer as an ID that doesn't exist (ST-12)
   */
  public static DisputeDetail getDispute(Id accountId, Id caseId) {
    DisputeDetail result = new DisputeDetail();
    setScopeOutcome(
      result,
      accountId,
      HouseholdScope.visibleHouseholds(new Set<Id>{ accountId })
    );
    if (result.outcome != StewardOutcome.COMPLETED) {
      return result;
    }
    if (accountId == null || caseId == null) {
      result.setOutcome(
        StewardOutcome.DECLINED_POLICY,
        StewardOutcome.INVALID_REQUEST
      );
      return result;
    }
    List<Case> found = [
      SELECT
        Id,
        AccountId,
        CaseNumber,
        Status,
        IsClosed,
        Dispute_Reason__c,
        Disputed_Statement__c,
        Disputed_Statement__r.Name,
        CreatedDate
      FROM Case
      WHERE
        Id = :caseId
        AND AccountId = :accountId
        AND RecordType.DeveloperName = :DISPUTE_RECORD_TYPE
      WITH USER_MODE
      LIMIT 1
    ];
    if (found.isEmpty()) {
      result.setOutcome(
        StewardOutcome.DECLINED_POLICY,
        StewardOutcome.NOT_FOUND
      );
      return result;
    }
    result.dispute = toView(found[0]);
    result.evidence = DisputeEvidenceCatalog.evidenceFor(
      found[0].Dispute_Reason__c
    );
    return result;
  }

  private static void setScopeOutcome(
    StewardOutcome.Result result,
    Id accountId,
    Set<Id> visible
  ) {
    if (accountId == null) {
      result.setOutcome(
        StewardOutcome.DECLINED_POLICY,
        StewardOutcome.INVALID_REQUEST
      );
    } else if (visible.contains(accountId)) {
      result.setOutcome(StewardOutcome.COMPLETED, null);
    } else {
      result.setOutcome(
        StewardOutcome.DECLINED_POLICY,
        StewardOutcome.NOT_FOUND
      );
    }
  }

  private static DisputeView toView(Case dispute) {
    DisputeView view = new DisputeView();
    view.caseId = dispute.Id;
    view.caseNumber = dispute.CaseNumber;
    view.status = dispute.Status;
    view.isClosed = dispute.IsClosed;
    view.reason = dispute.Dispute_Reason__c;
    view.statementId = dispute.Disputed_Statement__c;
    view.statementNumber = dispute.Disputed_Statement__r?.Name;
    view.openedDate = dispute.CreatedDate?.date();
    return view;
  }
}
