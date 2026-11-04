/**
 * ST-05, S-28, NFR-07. Records every call Steward makes to an outside system on
 * Integration_Log__c: the provider, the operation, the outcome, the HTTP status, how long it took,
 * and the household and statement it was for. Support staff use it to answer "did the payment
 * reach Stripe, and what did Stripe say?" without reading code or debug logs.
 *
 * Salesforce refuses a callout once a transaction has saved anything, so calls are kept in memory
 * as they happen and saved together with save(), after the last callout. A log that can't be
 * saved never breaks the payment it describes.
 */
public with sharing class IntegrationLogger {
  /** The outcome of a call that got a 2xx answer. */
  public static final String SUCCEEDED = 'Succeeded';
  /** The outcome of any other call: another status, a timeout, or an answer Steward couldn't read. */
  public static final String FAILED = 'Failed';

  private static List<Call> pending = new List<Call>();

  /** One call to an outside system. */
  public class Call {
    /** The provider, such as Stripe. */
    public String provider;
    /** What was asked, such as Create checkout session. */
    public String operation;
    /** SUCCEEDED or FAILED. */
    public String outcome;
    /** The HTTP status, or null when no answer arrived. */
    public Integer statusCode;
    /** How long the call took, in milliseconds. */
    public Long durationMs;
    /** The household, when the call was for one. */
    public Id accountId;
    /** The statement, when the call was about one. */
    public Id statementId;
    /** The provider's ID for what the call created or read. */
    public String providerReference;
    /** The provider's error type and code, and Steward's note. Never a key or card details. */
    public String details;

    /**
     * A call to record.
     * @param provider the provider, such as Stripe
     * @param operation what was asked
     */
    public Call(String provider, String operation) {
      this.provider = provider;
      this.operation = operation;
    }
  }

  /**
   * Keeps a call to save later with save().
   * @param call the call
   */
  public static void record(Call call) {
    if (call != null) {
      pending.add(call);
    }
  }

  /**
   * How many calls are waiting to be saved.
   * @return the count
   */
  public static Integer pendingCount() {
    return pending.size();
  }

  /**
   * Saves every call kept since the last save, in one statement. Call it after the transaction's
   * last callout. A row refused for its links, such as a statement that doesn't exist, is saved
   * again without them, with the IDs in its details. Any other refusal is left out, never thrown.
   * @return the saved logs' numbers, such as INT-000012, keyed by ID
   */
  public static Map<Id, String> save() {
    List<Integration_Log__c> rows = new List<Integration_Log__c>();
    for (Call call : pending) {
      rows.add(toRow(call));
    }
    pending = new List<Call>();
    if (rows.isEmpty()) {
      return new Map<Id, String>();
    }
    return new Elevated().insertRows(rows);
  }

  @TestVisible
  private static Integration_Log__c toRow(Call call) {
    return new Integration_Log__c(
      Provider__c = fit(call.provider, Integration_Log__c.Provider__c),
      Operation__c = fit(call.operation, Integration_Log__c.Operation__c),
      Outcome__c = call.outcome == SUCCEEDED ? SUCCEEDED : FAILED,
      Status_Code__c = call.statusCode,
      Duration_Ms__c = call.durationMs,
      Account__c = call.accountId,
      Billing_Statement__c = call.statementId,
      Provider_Reference__c = fit(
        call.providerReference,
        Integration_Log__c.Provider_Reference__c
      ),
      Details__c = fit(
        SensitiveText.redact(call.details),
        Integration_Log__c.Details__c
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

  // S-28: the log is written in system mode and without sharing. A customer paying on the portal,
  // the agent sending a link and the reconciliation job all have their calls recorded, and none of
  // them needs any access to the log. Reading it stays with support staff and admins.
  private without sharing class Elevated {
    /**
     * Saves the rows and reads back the numbers of those saved.
     * @param rows the log records
     * @return each saved record's number, keyed by ID
     */
    public Map<Id, String> insertRows(List<Integration_Log__c> rows) {
      Set<Id> saved = new Set<Id>();
      List<Integration_Log__c> unlinked = new List<Integration_Log__c>();
      List<Database.SaveResult> results = Database.insert(
        rows,
        false,
        AccessLevel.SYSTEM_MODE
      );
      for (Integer i = 0; i < results.size(); i++) {
        if (results[i].isSuccess()) {
          saved.add(results[i].getId());
        } else if (hasLinks(rows[i])) {
          unlinked.add(withoutLinks(rows[i]));
        }
      }
      if (!unlinked.isEmpty()) {
        for (
          Database.SaveResult result : Database.insert(
            unlinked,
            false,
            AccessLevel.SYSTEM_MODE
          )
        ) {
          if (result.isSuccess()) {
            saved.add(result.getId());
          }
        }
      }
      Map<Id, String> numbers = new Map<Id, String>();
      for (Integration_Log__c row : [
        SELECT Id, Name
        FROM Integration_Log__c
        WHERE Id IN :saved
        WITH SYSTEM_MODE
        ORDER BY Name
      ]) {
        numbers.put(row.Id, row.Name);
      }
      return numbers;
    }

    private Boolean hasLinks(Integration_Log__c row) {
      return row.Account__c != null || row.Billing_Statement__c != null;
    }

    /**
     * The row again, without the links the platform refused, such as a statement that doesn't
     * exist, and with their IDs at the start of its details instead.
     * @param row the refused row
     * @return a new row to save
     */
    private Integration_Log__c withoutLinks(Integration_Log__c row) {
      Integration_Log__c copy = row.clone(false, true);
      List<String> links = new List<String>();
      if (row.Account__c != null) {
        links.add('household ' + row.Account__c);
      }
      if (row.Billing_Statement__c != null) {
        links.add('statement ' + row.Billing_Statement__c);
      }
      copy.Account__c = null;
      copy.Billing_Statement__c = null;
      copy.Details__c = fit(
        'Not linked: ' +
          String.join(links, ', ') +
          '. ' +
          (row.Details__c == null ? '' : row.Details__c),
        Integration_Log__c.Details__c
      );
      return copy;
    }
  }
}
