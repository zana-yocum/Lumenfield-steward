/**
 * ST-02, S-08, ST-12, NFR-07. Serves the portal's What We Promised You page: the commitments
 * recorded on the logged-in household's agreement, through the scoped read service, with only the
 * five fields a customer may see. The household comes from the login, never from the browser.
 */
public with sharing class PortalCommitmentsController {
  /**
   * The logged-in household's commitments.
   * @return the commitments; an empty list when none were recorded at signing
   */
  @AuraEnabled
  public static CommitmentReadService.HouseholdCommitments getMyCommitments() {
    Id householdId;
    try {
      householdId = PortalHousehold.current();
      return CommitmentReadService.forHousehold(householdId);
    } catch (Exception error) {
      CommitmentReadService.HouseholdCommitments failed = new CommitmentReadService.HouseholdCommitments();
      new PortalFailure(
          householdId,
          'PortalCommitmentsController.getMyCommitments'
        )
        .recordException(failed, error);
      return failed;
    }
  }
}
