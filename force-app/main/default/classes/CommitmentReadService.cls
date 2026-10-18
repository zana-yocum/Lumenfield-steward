/**
 * ST-02, ST-12, S-08. The commitments recorded at signing for a household, as five fields: type,
 * value, months covered, terms and status. Commitments belong to opportunities, and customers and
 * the agent can't be given opportunity access, so this is the one Steward read that runs outside
 * user mode. It reads only for households the caller has already shown, in user mode, that it can
 * see; it filters on Commitment__c.Account__c (Accord's DEF-07); and nothing else leaves the
 * class: no opportunity, amount, stage, sales rep or who recorded it.
 */
public with sharing class CommitmentReadService {
  /** The household has no commitments on record. */
  public static final String NONE_RECORDED = 'NONE_RECORDED';

  /** One household's commitments. */
  public class HouseholdCommitments extends StewardOutcome.Result {
    @AuraEnabled
    public Id accountId;
    @AuraEnabled
    public List<CommitmentView> commitments = new List<CommitmentView>();
  }

  /** The five fields a customer may see. Nothing else is copied out of Commitment__c. */
  public class CommitmentView {
    @AuraEnabled
    public String commitmentType;
    @AuraEnabled
    public Decimal value;
    @AuraEnabled
    public Integer monthsCovered;
    @AuraEnabled
    public String terms;
    @AuraEnabled
    public String status;
  }

  /**
   * One household's commitments.
   * @param accountId the verified household
   * @return its commitments; NOT_FOUND when the caller can't see the household
   */
  public static HouseholdCommitments forHousehold(Id accountId) {
    return forHouseholds(new Set<Id>{ accountId }).get(accountId);
  }

  /**
   * Commitments for many households, in two queries.
   * @param accountIds the households to read
   * @return one result per requested ID, keyed by that ID
   */
  public static Map<Id, HouseholdCommitments> forHouseholds(
    Set<Id> accountIds
  ) {
    Map<Id, HouseholdCommitments> results = new Map<Id, HouseholdCommitments>();
    if (accountIds == null) {
      return results;
    }
    // The gate: user mode decides which households are in reach before anything is elevated.
    Set<Id> visible = HouseholdScope.visibleHouseholds(accountIds);
    for (Id accountId : accountIds) {
      HouseholdCommitments household = new HouseholdCommitments();
      household.accountId = accountId;
      if (accountId == null) {
        household.setOutcome(
          StewardOutcome.DECLINED_POLICY,
          StewardOutcome.INVALID_REQUEST
        );
      } else if (!visible.contains(accountId)) {
        household.setOutcome(
          StewardOutcome.DECLINED_POLICY,
          StewardOutcome.NOT_FOUND
        );
      } else {
        household.setOutcome(StewardOutcome.COMPLETED, NONE_RECORDED);
      }
      results.put(accountId, household);
    }
    if (visible.isEmpty()) {
      return results;
    }
    for (Commitment__c commitment : new Elevated().commitmentsFor(visible)) {
      HouseholdCommitments household = results.get(commitment.Account__c);
      household.commitments.add(toView(commitment));
      household.setOutcome(StewardOutcome.COMPLETED, null);
    }
    return results;
  }

  private static CommitmentView toView(Commitment__c commitment) {
    CommitmentView view = new CommitmentView();
    view.commitmentType = commitment.Type__c;
    view.value = commitment.Value__c;
    view.monthsCovered = commitment.Months_Covered__c == null
      ? null
      : commitment.Months_Covered__c.intValue();
    view.terms = commitment.Terms__c;
    view.status = commitment.Status__c;
    return view;
  }

  // S-08: commitments are read here in system mode and without sharing, because customers and
  // the agent can't be given access to the opportunities that own them. Only households already
  // proven visible are passed in, and only the five customer fields (plus the account, to group
  // by) are selected.
  private without sharing class Elevated {
    /**
     * The commitments of households already shown to be visible, five customer fields only.
     * @param householdIds households that passed HouseholdScope
     * @return their commitments, grouped by account, in type order
     */
    public List<Commitment__c> commitmentsFor(Set<Id> householdIds) {
      return [
        SELECT
          Account__c,
          Type__c,
          Value__c,
          Months_Covered__c,
          Terms__c,
          Status__c
        FROM Commitment__c
        WHERE Account__c IN :householdIds
        WITH SYSTEM_MODE
        ORDER BY Account__c, Type__c, Name
      ];
    }
  }
}
