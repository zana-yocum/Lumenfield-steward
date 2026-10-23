/**
 * ST-08, ST-09, S-20. One line for each kind of record the rep assistant writes into a prompt: a
 * statement, a payment, a promise, a billing dispute, a commitment and a contact attempt. The
 * briefing and the dispute summary share them, so a record reads the same way in both. Anything
 * a person typed goes through PromptFormat.quoted.
 */
public with sharing class RecordLines {
  /** The promise statuses that still have a date to keep. */
  public static final Set<String> OPEN_PROMISE_STATUSES = new Set<String>{
    'Active',
    'Pending Approval'
  };

  private static final Integer MAX_TERMS_LENGTH = 600;
  private static final Integer MAX_NOTES_LENGTH = 400;

  /**
   * An unpaid statement: number, due date, balance and status.
   * @param statement the statement
   * @return the line
   */
  public static String unpaidStatement(Billing_Statement__c statement) {
    return statement.Name +
      ': due ' +
      PromptFormat.day(statement.Due_Date__c) +
      ', balance ' +
      PromptFormat.money(statement.Balance__c) +
      ', status ' +
      PromptFormat.orNotRecorded(statement.Status__c);
  }

  /**
   * A disputed statement in full: dates, amount due, paid, credits, balance and status.
   * @param statement the statement, or null
   * @return the line; "None recorded." for null
   */
  public static String disputedStatement(Billing_Statement__c statement) {
    if (statement == null) {
      return 'None recorded.';
    }
    return statement.Name +
      ': dated ' +
      PromptFormat.day(statement.Statement_Date__c) +
      ', due ' +
      PromptFormat.day(statement.Due_Date__c) +
      ', amount due ' +
      PromptFormat.money(statement.Amount_Due__c) +
      ', paid ' +
      PromptFormat.money(statement.Amount_Paid__c) +
      ', credits applied ' +
      PromptFormat.money(statement.Credits_Applied__c) +
      ', balance ' +
      PromptFormat.money(statement.Balance__c) +
      ', status ' +
      PromptFormat.orNotRecorded(statement.Status__c);
  }

  /**
   * A payment's date and amount, and its method only when the query read it. The method is
   * queried only for someone who can read it (PS_Payment_Detail), so it's never guessed at here.
   * @param payment the payment
   * @return the line
   */
  public static String payment(Payment__c payment) {
    String method = payment.getPopulatedFieldsAsMap().containsKey('Method__c')
      ? payment.Method__c
      : null;
    return PromptFormat.day(payment.Payment_Date__c) +
      ': ' +
      PromptFormat.money(payment.Amount__c) +
      (String.isBlank(method) ? '' : ', by ' + method);
  }

  /**
   * A promise: when it was made, the amount and date, the status, and the grace date while it's
   * open or what was received once it's judged.
   * @param promise the promise
   * @return the line
   */
  public static String promise(Promise_to_Pay__c promise) {
    String line =
      'Made ' +
      PromptFormat.day(promise.CreatedDate.date()) +
      ': ' +
      PromptFormat.money(promise.Promise_Amount__c) +
      ' promised for ' +
      PromptFormat.day(promise.Promise_Date__c) +
      ', status ' +
      PromptFormat.orNotRecorded(promise.Status__c);
    if (OPEN_PROMISE_STATUSES.contains(promise.Status__c)) {
      return line + ', grace ends ' + PromptFormat.day(promise.Grace_Ends__c);
    }
    return promise.Amount_Received__c == null
      ? line
      : line +
        ', ' +
        PromptFormat.money(promise.Amount_Received__c) +
        ' received';
  }

  /**
   * An open billing dispute: number, reason, status, when it was opened, its statement, and its
   * next SLA milestone.
   * @param dispute the case, with Disputed_Statement__r.Name
   * @param milestone the next milestone, as SlaMilestones writes it
   * @return the line
   */
  public static String dispute(Case dispute, String milestone) {
    return dispute.CaseNumber +
      ': ' +
      PromptFormat.orNotRecorded(dispute.Dispute_Reason__c) +
      ', status ' +
      dispute.Status +
      ', opened ' +
      PromptFormat.day(dispute.CreatedDate.date()) +
      ', on statement ' +
      dispute.Disputed_Statement__r?.Name +
      '. Next SLA milestone: ' +
      milestone;
  }

  /**
   * A commitment's type, value, months covered and status, then its terms as quoted text.
   * @param commitment the commitment
   * @param note added after the status, such as the dispute summary's match flag; may be blank
   * @return the line
   */
  public static String commitment(Commitment__c commitment, String note) {
    return PromptFormat.orNotRecorded(commitment.Type__c) +
      ', value ' +
      PromptFormat.moneyOr(commitment.Value__c, 'none (not a dollar amount)') +
      monthsCovered(commitment.Months_Covered__c) +
      ', status ' +
      PromptFormat.orNotRecorded(commitment.Status__c) +
      '.' +
      (String.isBlank(note) ? '' : note) +
      ' Terms: ' +
      PromptFormat.quoted(commitment.Terms__c, MAX_TERMS_LENGTH);
  }

  // ", 1 month covered" or ", 3 months covered"; nothing when the commitment covers no months.
  private static String monthsCovered(Decimal months) {
    if (months == null) {
      return '';
    }
    String count = PromptFormat.wholeNumber(months);
    return ', ' + count + (count == '1' ? ' month covered' : ' months covered');
  }

  /**
   * A contact attempt: the day it was logged, its outcome, and the rep's notes as quoted text.
   * @param attempt the task
   * @return the line
   */
  public static String contactAttempt(Task attempt) {
    return PromptFormat.day(attempt.CreatedDate.date()) +
      ': ' +
      attempt.Contact_Outcome__c +
      (String.isBlank(attempt.Description)
        ? '.'
        : '. Notes: ' +
          PromptFormat.quoted(attempt.Description, MAX_NOTES_LENGTH));
  }
}
