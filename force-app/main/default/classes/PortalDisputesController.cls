/**
 * ST-06, ST-12, NFR-07. Serves the portal's Disputes pages: the household's disputes, the form
 * that opens one, and a single dispute with its evidence list. The household always comes from
 * the login (PortalHousehold); IDs from the page are only ever looked for inside it. Opening a
 * dispute goes through DisputeIntakeService, so Accord's flows, SLA and assignment rule apply
 * exactly as when a rep opens one. Failures come back as a reference to quote, never an error.
 */
public with sharing class PortalDisputesController {
  /** A statement the customer can choose on the form, or one that's already disputed. */
  public class StatementOption {
    @AuraEnabled
    public Id statementId;
    @AuraEnabled
    public String statementNumber;
    @AuraEnabled
    public Date statementDate;
    @AuraEnabled
    public Decimal amountDue;
    /** The open dispute on this statement, if there is one. */
    @AuraEnabled
    public Id disputeCaseId;
    @AuraEnabled
    public String disputeCaseNumber;
  }

  /** What the form needs: the eight reasons with their evidence, and the household's statements. */
  public class DisputeForm extends StewardOutcome.Result {
    @AuraEnabled
    public List<DisputeEvidenceCatalog.ReasonOption> reasons = new List<DisputeEvidenceCatalog.ReasonOption>();
    @AuraEnabled
    public List<StatementOption> statements = new List<StatementOption>();
  }

  /**
   * The logged-in household's disputes, newest first.
   * @return the disputes
   */
  @AuraEnabled
  public static DisputeStatusService.HouseholdDisputes getMyDisputes() {
    Id householdId;
    try {
      householdId = PortalHousehold.current();
      return DisputeStatusService.forHousehold(householdId);
    } catch (Exception error) {
      DisputeStatusService.HouseholdDisputes failed = new DisputeStatusService.HouseholdDisputes();
      new PortalFailure(householdId, 'PortalDisputesController.getMyDisputes')
        .recordException(failed, error);
      return failed;
    }
  }

  /**
   * The choices for a new dispute.
   * @return the reasons and statements; NOT_FOUND for a user with no household
   */
  @AuraEnabled
  public static DisputeForm getDisputeForm() {
    DisputeForm form = new DisputeForm();
    Id householdId;
    try {
      householdId = PortalHousehold.current();
      AccountSnapshotService.Snapshot snapshot = AccountSnapshotService.getSnapshot(
        householdId
      );
      form.setOutcome(snapshot.outcome, snapshot.reasonCode);
      if (snapshot.outcome != StewardOutcome.COMPLETED) {
        return form;
      }
      form.reasons = DisputeEvidenceCatalog.getReasons();
      for (AccountSnapshotService.StatementLine line : snapshot.statements) {
        form.statements.add(toOption(line));
      }
      return form;
    } catch (Exception error) {
      new PortalFailure(householdId, 'PortalDisputesController.getDisputeForm')
        .recordException(form, error);
      return form;
    }
  }

  /**
   * One of the household's disputes, with what to send for its reason.
   * @param caseId the dispute on the page
   * @return the dispute; NOT_FOUND when it isn't one of the household's
   */
  @AuraEnabled
  public static DisputeStatusService.DisputeDetail getDispute(Id caseId) {
    Id householdId;
    try {
      householdId = PortalHousehold.current();
      return DisputeStatusService.getDispute(householdId, caseId);
    } catch (Exception error) {
      DisputeStatusService.DisputeDetail failed = new DisputeStatusService.DisputeDetail();
      new PortalFailure(householdId, 'PortalDisputesController.getDispute')
        .recordException(failed, error);
      return failed;
    }
  }

  /**
   * Opens a dispute on one of the household's statements, once the customer has confirmed it.
   * @param statementId the statement
   * @param reason one of the eight dispute reasons
   * @param description the customer's own words, optional; card numbers are removed
   * @return the case number and evidence list, a decline with its reason, or a failure with a
   *   reference to quote
   */
  @AuraEnabled
  public static DisputeIntakeService.DisputeResult openDispute(
    Id statementId,
    String reason,
    String description
  ) {
    DisputeIntakeService.DisputeResult result = new DisputeIntakeService.DisputeResult();
    Id householdId;
    try {
      householdId = PortalHousehold.current();
      DisputeIntakeService.Request request = new DisputeIntakeService.Request(
        householdId,
        statementId,
        reason
      );
      request.description = description;
      result = DisputeIntakeService.openDispute(request);
      if (result.outcome == StewardOutcome.FAILED) {
        new PortalFailure(householdId, 'PortalDisputesController.openDispute')
          .record(result, result.reasonCode + ': ' + result.failureDetail);
        result.failureDetail = null;
      }
      return result;
    } catch (Exception error) {
      new PortalFailure(householdId, 'PortalDisputesController.openDispute')
        .recordException(result, error);
      return result;
    }
  }

  private static StatementOption toOption(
    AccountSnapshotService.StatementLine line
  ) {
    StatementOption option = new StatementOption();
    option.statementId = line.statementId;
    option.statementNumber = line.statementNumber;
    option.statementDate = line.statementDate;
    option.amountDue = line.amountDue;
    option.disputeCaseId = line.disputeCaseId;
    option.disputeCaseNumber = line.disputeCaseNumber;
    return option;
  }
}
