/**
 * ST-11, S-09, GR-06. Writes one Agent_Action_Log__c record per agent action: the household it
 * served, the action, the outcome and the reason. Declined and failed requests are logged too,
 * because nothing else in the org records them. Card numbers are removed and long text is cut to
 * fit before anything is saved, and a log that can't be saved never breaks the action.
 */
public with sharing class AgentActionLogger {
  /** One action to record. */
  public class Entry {
    /** The verified household (S-07). */
    public Id accountId;
    /** The action's Apex class name. */
    public String action;
    /** One of the StewardOutcome codes. */
    public String outcome;
    /** The service's reason code, if any. */
    public String reasonCode;
    /** A short line saying what was asked. Card numbers are removed before saving. */
    public String details;
    /** The conversation the action ran in. */
    public String conversationId;

    /**
     * An entry for a service's result, with its outcome and reason.
     * @param accountId the verified household
     * @param action the action's Apex class name
     * @param result what the service returned
     */
    public Entry(Id accountId, String action, StewardOutcome.Result result) {
      this.accountId = accountId;
      this.action = action;
      this.outcome = result?.outcome;
      this.reasonCode = result?.reasonCode;
    }
  }

  /**
   * Records one action.
   * @param entry what happened
   * @return the save result, or null when there was nothing to save
   */
  public static Database.SaveResult log(Entry entry) {
    List<Database.SaveResult> results = log(new List<Entry>{ entry });
    return results.isEmpty() ? null : results[0];
  }

  /**
   * Records actions in one save. Entries that fail to save are reported, not thrown.
   * @param entries what happened; nulls are skipped
   * @return one save result per saved entry, in order
   */
  public static List<Database.SaveResult> log(List<Entry> entries) {
    List<Agent_Action_Log__c> rows = new List<Agent_Action_Log__c>();
    if (entries != null) {
      for (Entry entry : entries) {
        if (entry != null) {
          rows.add(toRow(entry));
        }
      }
    }
    if (rows.isEmpty()) {
      return new List<Database.SaveResult>();
    }
    return new Elevated().insertRows(rows);
  }

  @TestVisible
  private static Agent_Action_Log__c toRow(Entry entry) {
    String label = StewardOutcome.logLabel(entry.outcome);
    String details = entry.details;
    if (label == null) {
      // An unknown code is a bug in the caller. Record it as a failure rather than lose the entry.
      label = StewardOutcome.logLabel(StewardOutcome.FAILED);
      details =
        'Unknown outcome code: ' +
        entry.outcome +
        (String.isBlank(details) ? '' : '. ' + details);
    }
    return new Agent_Action_Log__c(
      Account__c = entry.accountId,
      Action__c = fit(entry.action, Agent_Action_Log__c.Action__c),
      Outcome__c = label,
      Reason_Code__c = fit(
        entry.reasonCode,
        Agent_Action_Log__c.Reason_Code__c
      ),
      Details__c = fit(
        SensitiveText.redact(details),
        Agent_Action_Log__c.Details__c
      ),
      Conversation_Id__c = fit(
        entry.conversationId,
        Agent_Action_Log__c.Conversation_Id__c
      )
    );
  }

  private static String fit(String value, Schema.SObjectField field) {
    if (value == null) {
      return null;
    }
    Integer maxLength = field.getDescribe().getLength();
    return value.length() > maxLength ? value.left(maxLength) : value;
  }

  // S-09: the log is written in system mode and without sharing, so a declined or failed request
  // is recorded even when the caller can't see the account it named, and the agent user needs no
  // access to the log object at all. Reading the log stays with supervisors and admins (ST-11).
  private without sharing class Elevated {
    /**
     * Saves the rows; a row that fails is reported in its result, never thrown.
     * @param rows the log records
     * @return one save result per row
     */
    public List<Database.SaveResult> insertRows(
      List<Agent_Action_Log__c> rows
    ) {
      return Database.insert(rows, false, AccessLevel.SYSTEM_MODE);
    }
  }
}
