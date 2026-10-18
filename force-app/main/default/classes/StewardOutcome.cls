/**
 * ST-11, GR-04, GR-06. The outcome codes every Steward service returns, and the result they
 * all extend. Services return codes, never sentences: the agent puts them into words, and
 * supervisors see the matching label on Agent_Action_Log__c.
 */
public with sharing class StewardOutcome {
  /** The service did what was asked. */
  public static final String COMPLETED = 'COMPLETED';
  /** A rule said no. The reason code says which one. */
  public static final String DECLINED_POLICY = 'DECLINED_POLICY';
  /** A person has to take it from here (ST-07). */
  public static final String HANDOFF = 'HANDOFF';
  /** Something broke. The customer gets a reference, never the error (NFR-07). */
  public static final String FAILED = 'FAILED';

  /**
   * A household or record outside the caller's reach. Deliberately the same answer as a record
   * that doesn't exist, so a guessed ID confirms nothing (ST-12).
   */
  public static final String NOT_FOUND = 'NOT_FOUND';
  /** The request was missing something it needs. */
  public static final String INVALID_REQUEST = 'INVALID_REQUEST';

  private static final Map<String, String> LOG_LABELS = new Map<String, String>{
    COMPLETED => 'Completed',
    DECLINED_POLICY => 'Declined by Policy',
    HANDOFF => 'Handed Off',
    FAILED => 'Failed'
  };

  /**
   * The Agent_Action_Log__c.Outcome__c label for an outcome code.
   * @param outcome one of the four outcome codes
   * @return the label, or null if the code isn't one of the four
   */
  public static String logLabel(String outcome) {
    return outcome == null ? null : LOG_LABELS.get(outcome);
  }

  /**
   * The platform's errors from a failed save, as one line for a log. Never shown to a customer.
   * @param errors the errors from a SaveResult
   * @return status codes and messages, separated by semicolons
   */
  public static String describeErrors(List<Database.Error> errors) {
    List<String> parts = new List<String>();
    if (errors != null) {
      for (Database.Error error : errors) {
        parts.add(
          String.valueOf(error.getStatusCode()) + ': ' + error.getMessage()
        );
      }
    }
    return String.join(parts, '; ');
  }

  /** What every service result carries: an outcome code and, where it helps, a reason code. */
  public virtual class Result {
    @AuraEnabled
    public String outcome;
    @AuraEnabled
    public String reasonCode;

    /**
     * Sets the outcome and the reason together, so one is never changed without the other.
     * @param outcome one of the four outcome codes
     * @param reasonCode why, or null when there's nothing to add
     */
    public void setOutcome(String outcome, String reasonCode) {
      this.outcome = outcome;
      this.reasonCode = reasonCode;
    }
  }
}
