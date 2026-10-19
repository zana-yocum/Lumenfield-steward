/**
 * ST-01, ST-12, NFR-07. Serves the portal's My Account, Statements and statement pages. The
 * household always comes from the login (PortalHousehold). No method takes an account ID, and a
 * statement asked for by ID is looked for only among the logged-in household's own, so another
 * household's ID finds nothing: the page isn't the security boundary, the server is. Failures
 * come back as a reference to quote, never as an error.
 */
public with sharing class PortalAccountController {
  /** One statement, with its payments and any open dispute. */
  public class StatementResult extends StewardOutcome.Result {
    @AuraEnabled
    public AccountSnapshotService.StatementLine statement;
  }

  /**
   * The logged-in household's balances, statements with their payments, and open promise.
   * @return the snapshot; NOT_FOUND or INVALID_REQUEST for a user with no household
   */
  @AuraEnabled
  public static AccountSnapshotService.Snapshot getMyAccount() {
    Id householdId;
    try {
      householdId = PortalHousehold.current();
      return AccountSnapshotService.getSnapshot(householdId);
    } catch (Exception error) {
      AccountSnapshotService.Snapshot failed = new AccountSnapshotService.Snapshot();
      new PortalFailure(householdId, 'PortalAccountController.getMyAccount')
        .recordException(failed, error);
      return failed;
    }
  }

  /**
   * One of the logged-in household's statements.
   * @param statementId the statement on the page
   * @return the statement; NOT_FOUND when it isn't one of the household's
   */
  @AuraEnabled
  public static StatementResult getStatement(Id statementId) {
    StatementResult result = new StatementResult();
    Id householdId;
    try {
      householdId = PortalHousehold.current();
      AccountSnapshotService.Snapshot snapshot = AccountSnapshotService.getSnapshot(
        householdId
      );
      result.setOutcome(snapshot.outcome, snapshot.reasonCode);
      if (snapshot.outcome != StewardOutcome.COMPLETED) {
        return result;
      }
      for (AccountSnapshotService.StatementLine line : snapshot.statements) {
        if (line.statementId == statementId) {
          result.statement = line;
          return result;
        }
      }
      result.setOutcome(
        StewardOutcome.DECLINED_POLICY,
        StewardOutcome.NOT_FOUND
      );
      return result;
    } catch (Exception error) {
      new PortalFailure(householdId, 'PortalAccountController.getStatement')
        .recordException(result, error);
      return result;
    }
  }
}
