/**
 * NFR-07, S-09. What the portal does with a failure: the details go to the action log, and the
 * customer gets only the log's number to quote, never the error. Covers both kinds: an exception
 * nobody planned for, and a failure a service reported, such as a save the platform rejected.
 * Each one is made where the failure happened, so the log says which household and which page.
 */
public with sharing class PortalFailure {
  /** The reason code on an exception nobody planned for. */
  public static final String UNEXPECTED_ERROR = 'UNEXPECTED_ERROR';

  private final Id accountId;
  private final String action;

  /**
   * Where a failure happened.
   * @param accountId the household, or null when it isn't known yet
   * @param action the controller method, such as PortalAccountController.getMyAccount
   */
  public PortalFailure(Id accountId, String action) {
    this.accountId = accountId;
    this.action = action;
  }

  /**
   * Logs an exception and turns the result into a failure that carries the reference.
   * @param result what the customer gets back; its outcome becomes FAILED
   * @param error the exception; recorded in the log only
   */
  public void recordException(StewardOutcome.Result result, Exception error) {
    result.setOutcome(StewardOutcome.FAILED, UNEXPECTED_ERROR);
    record(result, error.getTypeName() + ': ' + error.getMessage());
  }

  /**
   * Logs a failure a service reported and adds the reference to its result. The detail goes to
   * the log only; the caller clears it from anything the customer receives.
   * @param result the service's FAILED result
   * @param detail what went wrong, for the log
   */
  public void record(StewardOutcome.Result result, String detail) {
    AgentActionLogger.Entry entry = new AgentActionLogger.Entry(
      accountId,
      action,
      result
    );
    entry.details = detail;
    result.reference = AgentActionLogger.logForReference(entry);
  }
}
