/**
 * ST-01, ST-12, GR-04. Where a household stands: its balances, its statements newest first with
 * the payments under each, any open dispute on a statement, and any open promise to pay. It reads
 * Accord's roll-ups and formulas instead of recalculating them, so the portal, the agent and a
 * rep see the same numbers. Runs in user mode: a household the caller can't see is NOT_FOUND.
 */
public with sharing class AccountSnapshotService {
  private static final String DISPUTE_RECORD_TYPE = 'Billing_Dispute';
  private static final String STATEMENT_OPEN = 'Open';
  private static final Set<String> OPEN_PROMISE_STATUSES = new Set<String>{
    'Active',
    'Pending Approval'
  };

  /** One household's position. */
  public class Snapshot extends StewardOutcome.Result {
    @AuraEnabled
    public Id accountId;
    /** Accord's Current_Balance__c: what's owed across all statements. */
    @AuraEnabled
    public Decimal currentBalance;
    /** Accord's Past_Due_Balance__c. */
    @AuraEnabled
    public Decimal pastDueBalance;
    /** Accord's Oldest_Past_Due_Date__c: the due date of the oldest past-due statement. */
    @AuraEnabled
    public Date oldestPastDueDate;
    /** The earliest due date among Open statements that still have a balance. */
    @AuraEnabled
    public Date nextDueDate;
    /** That statement's balance. */
    @AuraEnabled
    public Decimal nextDueAmount;
    /** Newest first. */
    @AuraEnabled
    public List<StatementLine> statements = new List<StatementLine>();
    /** The Active or Pending Approval promise to pay, if there is one. */
    @AuraEnabled
    public PromiseLine openPromise;
  }

  /** One statement, as a customer sees it. */
  public class StatementLine {
    @AuraEnabled
    public Id statementId;
    @AuraEnabled
    public String statementNumber;
    @AuraEnabled
    public Date statementDate;
    @AuraEnabled
    public Date dueDate;
    @AuraEnabled
    public Decimal amountDue;
    @AuraEnabled
    public Decimal amountPaid;
    @AuraEnabled
    public Decimal creditsApplied;
    @AuraEnabled
    public Decimal balance;
    @AuraEnabled
    public String status;
    @AuraEnabled
    public Boolean disputeOpen;
    /** The open Billing Dispute on this statement, if the caller can see it. */
    @AuraEnabled
    public Id disputeCaseId;
    @AuraEnabled
    public String disputeCaseNumber;
    /** Newest first. */
    @AuraEnabled
    public List<PaymentLine> payments = new List<PaymentLine>();
  }

  /** Date and amount only. Payment method and processor reference stay with supervisors (ST-01). */
  public class PaymentLine {
    @AuraEnabled
    public Id paymentId;
    @AuraEnabled
    public String paymentNumber;
    @AuraEnabled
    public Date paymentDate;
    @AuraEnabled
    public Decimal amount;
  }

  /** An open promise to pay. */
  public class PromiseLine {
    @AuraEnabled
    public Id promiseId;
    @AuraEnabled
    public Decimal amount;
    @AuraEnabled
    public Date promiseDate;
    @AuraEnabled
    public String status;
    /** Accord's Grace_Ends__c: the promise date plus the grace days. */
    @AuraEnabled
    public Date graceEnds;
  }

  /**
   * One household's snapshot.
   * @param accountId the verified household
   * @return its snapshot; NOT_FOUND when the caller can't see it
   */
  public static Snapshot getSnapshot(Id accountId) {
    return getSnapshots(new Set<Id>{ accountId }).get(accountId);
  }

  /**
   * Snapshots for many households, with the same six queries however many there are.
   * @param accountIds the households to read
   * @return one snapshot per requested ID, keyed by that ID
   */
  public static Map<Id, Snapshot> getSnapshots(Set<Id> accountIds) {
    Map<Id, Snapshot> results = new Map<Id, Snapshot>();
    if (accountIds == null) {
      return results;
    }
    Set<Id> visible = HouseholdScope.visibleHouseholds(accountIds);
    for (Id accountId : accountIds) {
      results.put(accountId, newSnapshot(accountId, visible));
    }
    if (!visible.isEmpty()) {
      addBalances(results, visible);
      Map<Id, StatementLine> linesById = addStatements(results, visible);
      addPayments(linesById);
      addOpenDisputes(linesById);
      addOpenPromises(results, visible);
    }
    return results;
  }

  private static Snapshot newSnapshot(Id accountId, Set<Id> visible) {
    Snapshot snapshot = new Snapshot();
    snapshot.accountId = accountId;
    if (accountId == null) {
      snapshot.setOutcome(
        StewardOutcome.DECLINED_POLICY,
        StewardOutcome.INVALID_REQUEST
      );
    } else if (visible.contains(accountId)) {
      snapshot.setOutcome(StewardOutcome.COMPLETED, null);
    } else {
      snapshot.setOutcome(
        StewardOutcome.DECLINED_POLICY,
        StewardOutcome.NOT_FOUND
      );
    }
    return snapshot;
  }

  private static void addBalances(Map<Id, Snapshot> results, Set<Id> visible) {
    for (Account household : [
      SELECT
        Id,
        Current_Balance__c,
        Past_Due_Balance__c,
        Oldest_Past_Due_Date__c
      FROM Account
      WHERE Id IN :visible
      WITH USER_MODE
    ]) {
      Snapshot snapshot = results.get(household.Id);
      snapshot.currentBalance = zeroIfNull(household.Current_Balance__c);
      snapshot.pastDueBalance = zeroIfNull(household.Past_Due_Balance__c);
      snapshot.oldestPastDueDate = household.Oldest_Past_Due_Date__c;
    }
  }

  private static Map<Id, StatementLine> addStatements(
    Map<Id, Snapshot> results,
    Set<Id> visible
  ) {
    Map<Id, StatementLine> linesById = new Map<Id, StatementLine>();
    for (Billing_Statement__c statement : [
      SELECT
        Id,
        Name,
        Account__c,
        Statement_Date__c,
        Due_Date__c,
        Amount_Due__c,
        Amount_Paid__c,
        Credits_Applied__c,
        Balance__c,
        Status__c,
        Dispute_Open__c
      FROM Billing_Statement__c
      WHERE Account__c IN :visible
      WITH USER_MODE
      ORDER BY Statement_Date__c DESC, Name DESC
    ]) {
      StatementLine line = toLine(statement);
      linesById.put(statement.Id, line);
      Snapshot snapshot = results.get(statement.Account__c);
      snapshot.statements.add(line);
      if (isNextDue(line, snapshot.nextDueDate)) {
        snapshot.nextDueDate = line.dueDate;
        snapshot.nextDueAmount = line.balance;
      }
    }
    return linesById;
  }

  private static void addPayments(Map<Id, StatementLine> linesById) {
    if (linesById.isEmpty()) {
      return;
    }
    for (Payment__c payment : [
      SELECT Id, Name, Billing_Statement__c, Payment_Date__c, Amount__c
      FROM Payment__c
      WHERE Billing_Statement__c IN :linesById.keySet()
      WITH USER_MODE
      ORDER BY Payment_Date__c DESC, Name DESC
    ]) {
      PaymentLine line = new PaymentLine();
      line.paymentId = payment.Id;
      line.paymentNumber = payment.Name;
      line.paymentDate = payment.Payment_Date__c;
      line.amount = payment.Amount__c;
      linesById.get(payment.Billing_Statement__c).payments.add(line);
    }
  }

  private static void addOpenDisputes(Map<Id, StatementLine> linesById) {
    if (linesById.isEmpty()) {
      return;
    }
    for (Case dispute : [
      SELECT Id, CaseNumber, Disputed_Statement__c
      FROM Case
      WHERE
        Disputed_Statement__c IN :linesById.keySet()
        AND RecordType.DeveloperName = :DISPUTE_RECORD_TYPE
        AND IsClosed = FALSE
      WITH USER_MODE
      ORDER BY CreatedDate ASC
    ]) {
      StatementLine line = linesById.get(dispute.Disputed_Statement__c);
      line.disputeCaseId = dispute.Id;
      line.disputeCaseNumber = dispute.CaseNumber;
    }
  }

  private static void addOpenPromises(
    Map<Id, Snapshot> results,
    Set<Id> visible
  ) {
    for (Promise_to_Pay__c promise : [
      SELECT
        Id,
        Account__c,
        Promise_Amount__c,
        Promise_Date__c,
        Status__c,
        Grace_Ends__c
      FROM Promise_to_Pay__c
      WHERE Account__c IN :visible AND Status__c IN :OPEN_PROMISE_STATUSES
      WITH USER_MODE
      ORDER BY Promise_Date__c DESC
    ]) {
      PromiseLine line = new PromiseLine();
      line.promiseId = promise.Id;
      line.amount = promise.Promise_Amount__c;
      line.promiseDate = promise.Promise_Date__c;
      line.status = promise.Status__c;
      line.graceEnds = promise.Grace_Ends__c;
      // Sorted latest first, so the earliest open promise is the one left in place.
      results.get(promise.Account__c).openPromise = line;
    }
  }

  private static Boolean isNextDue(StatementLine line, Date currentNextDue) {
    return line.status == STATEMENT_OPEN &&
      line.balance > 0 &&
      line.dueDate != null &&
      (currentNextDue == null ||
      line.dueDate < currentNextDue);
  }

  private static StatementLine toLine(Billing_Statement__c statement) {
    StatementLine line = new StatementLine();
    line.statementId = statement.Id;
    line.statementNumber = statement.Name;
    line.statementDate = statement.Statement_Date__c;
    line.dueDate = statement.Due_Date__c;
    line.amountDue = zeroIfNull(statement.Amount_Due__c);
    line.amountPaid = zeroIfNull(statement.Amount_Paid__c);
    line.creditsApplied = zeroIfNull(statement.Credits_Applied__c);
    line.balance = zeroIfNull(statement.Balance__c);
    line.status = statement.Status__c;
    line.disputeOpen = statement.Dispute_Open__c;
    return line;
  }

  private static Decimal zeroIfNull(Decimal value) {
    return value == null ? 0 : value;
  }
}
