/**
 * ST-12, GR-01, S-07. Decides whether a household is in reach. A household is a Residential
 * Agreement account the running user can see. Every Steward service asks here first, in user
 * mode, so an ID from someone else's household gets the same answer as an ID that doesn't exist.
 */
public with sharing class HouseholdScope {
  @TestVisible
  private static final String HOUSEHOLD_RECORD_TYPE = 'Residential_Agreement';

  /**
   * The households among the given account IDs that the running user can see.
   * @param accountIds account IDs to check; nulls are ignored
   * @return the subset that are visible Residential Agreement accounts
   */
  public static Set<Id> visibleHouseholds(Set<Id> accountIds) {
    Set<Id> visible = new Set<Id>();
    if (accountIds == null || accountIds.isEmpty()) {
      return visible;
    }
    Set<Id> candidates = new Set<Id>(accountIds);
    candidates.remove(null);
    if (candidates.isEmpty()) {
      return visible;
    }
    for (Account household : [
      SELECT Id
      FROM Account
      WHERE
        Id IN :candidates
        AND RecordType.DeveloperName = :HOUSEHOLD_RECORD_TYPE
      WITH USER_MODE
    ]) {
      visible.add(household.Id);
    }
    return visible;
  }

  /**
   * Whether one household is in reach.
   * @param accountId the account ID to check
   * @return true when it's a visible Residential Agreement account
   */
  public static Boolean isVisible(Id accountId) {
    return accountId != null &&
      visibleHouseholds(new Set<Id>{ accountId }).contains(accountId);
  }
}
