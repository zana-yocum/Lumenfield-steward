/**
 * ST-03, ST-12, GR-04. Explains a statement using only the household's own records: how its
 * amount due compares with the statement before it (the annual escalator, or no change), the
 * posted credits on it, and the unpaid earlier statements behind the balance. When the records
 * don't account for a change it says so (UNEXPLAINED_CHANGE) instead of guessing. Credits that
 * are Draft, Pending Approval or Rejected are never mentioned, so the agent never tells a customer
 * about money that may not come.
 */
public with sharing class StatementExplanationService {
  /** The amount due rose by the agreement's escalator rate at its anniversary. */
  public static final String ESCALATOR = 'ESCALATOR';
  /** A posted credit reduced what's owed on the statement. */
  public static final String POSTED_CREDIT = 'POSTED_CREDIT';
  /** An earlier statement still has a balance. */
  public static final String UNPAID_PRIOR_STATEMENT = 'UNPAID_PRIOR_STATEMENT';
  /** The amount due changed and the records don't say why. */
  public static final String UNEXPLAINED_CHANGE = 'UNEXPLAINED_CHANGE';
  /** The amount due is the same as on the statement before. */
  public static final String NO_CHANGE = 'NO_CHANGE';
  /** There's no earlier statement to compare with. */
  public static final String FIRST_STATEMENT = 'FIRST_STATEMENT';
  /** The household has no statements yet. */
  public static final String NO_STATEMENTS = 'NO_STATEMENTS';

  private static final String CREDIT_POSTED = 'Posted';
  private static final String STATEMENT_WRITTEN_OFF = 'Written Off';

  /** What to explain. */
  public class Request {
    /** The verified household (S-07). */
    public Id accountId;
    /** The statement to explain, or null for the latest. */
    public Id statementId;

    /**
     * A statement to explain.
     * @param accountId the verified household
     * @param statementId the statement to explain, or null for the latest
     */
    public Request(Id accountId, Id statementId) {
      this.accountId = accountId;
      this.statementId = statementId;
    }
  }

  /** The explanation for one statement. */
  public class Explanation extends StewardOutcome.Result {
    @AuraEnabled
    public StatementSummary statement;
    /** The statement before it, if any. */
    @AuraEnabled
    public StatementSummary priorStatement;
    /** The amount comparison first, then posted credits, then unpaid earlier statements. */
    @AuraEnabled
    public List<Reason> reasons = new List<Reason>();
    /** False when any reason is UNEXPLAINED_CHANGE: offer a dispute or a person, don't guess. */
    @AuraEnabled
    public Boolean fullyExplained = false;
  }

  /** The figures from one statement. */
  public class StatementSummary {
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
  }

  /** One reason, with the figures the agent quotes. Only the fields for its code are filled in. */
  public class Reason {
    @AuraEnabled
    public String code;
    /** The change in amount due, the credit amount, or the unpaid balance. */
    @AuraEnabled
    public Decimal amount;
    @AuraEnabled
    public Decimal amountBefore;
    @AuraEnabled
    public Decimal amountAfter;
    /** ESCALATOR: the agreement's rate, in percent. */
    @AuraEnabled
    public Decimal escalatorRatePct;
    /** ESCALATOR: the agreement anniversary the increase follows. */
    @AuraEnabled
    public Date anniversaryDate;
    /** POSTED_CREDIT: the adjustment type. */
    @AuraEnabled
    public String creditType;
    /** POSTED_CREDIT: when it posted. */
    @AuraEnabled
    public Date postedDate;
    /** UNPAID_PRIOR_STATEMENT: the earlier statement. */
    @AuraEnabled
    public Id statementId;
    @AuraEnabled
    public String statementNumber;
    @AuraEnabled
    public Date statementDate;
    @AuraEnabled
    public Date dueDate;
    @AuraEnabled
    public String statementStatus;
  }

  /**
   * Explains one statement.
   * @param accountId the verified household
   * @param statementId the statement, or null for the latest
   * @return the explanation; NOT_FOUND when the household or statement is out of reach
   */
  public static Explanation explain(Id accountId, Id statementId) {
    return explain(new List<Request>{ new Request(accountId, statementId) })[0];
  }

  /**
   * Explains many statements with three queries, however many there are.
   * @param requests what to explain
   * @return one explanation per request, in the same order
   */
  public static List<Explanation> explain(List<Request> requests) {
    List<Explanation> results = new List<Explanation>();
    if (requests == null) {
      return results;
    }
    HouseholdRecords records = new HouseholdRecords(requests);
    for (Request request : requests) {
      results.add(explainOne(request, records));
    }
    return results;
  }

  private static Explanation explainOne(
    Request request,
    HouseholdRecords records
  ) {
    Explanation explanation = new Explanation();
    if (request == null || request.accountId == null) {
      explanation.setOutcome(
        StewardOutcome.DECLINED_POLICY,
        StewardOutcome.INVALID_REQUEST
      );
      return explanation;
    }
    List<Billing_Statement__c> statements = records.statementsOf(
      request.accountId
    );
    Integer index = records.indexOf(request);
    if (index < 0) {
      // A household out of reach, or a statement from another household, looks exactly like one
      // that doesn't exist (ST-12).
      explanation.setOutcome(
        StewardOutcome.DECLINED_POLICY,
        StewardOutcome.NOT_FOUND
      );
    } else if (statements.isEmpty()) {
      explanation.fullyExplained = true;
      explanation.setOutcome(StewardOutcome.COMPLETED, NO_STATEMENTS);
    } else {
      addReasons(explanation, request, records);
    }
    return explanation;
  }

  private static void addReasons(
    Explanation explanation,
    Request request,
    HouseholdRecords records
  ) {
    List<Billing_Statement__c> statements = records.statementsOf(
      request.accountId
    );
    Integer index = records.indexOf(request);
    Billing_Statement__c target = statements[index];
    Billing_Statement__c prior = index + 1 < statements.size()
      ? statements[index + 1]
      : null;
    explanation.statement = summarize(target);
    explanation.priorStatement = prior == null ? null : summarize(prior);
    explanation.reasons.add(AmountDueComparison.compare(target, prior));
    for (Adjustment__c credit : records.postedCreditsOn(target.Id)) {
      explanation.reasons.add(postedCredit(credit));
    }
    for (Integer i = index + 1; i < statements.size(); i++) {
      if (isUnpaid(statements[i])) {
        explanation.reasons.add(unpaidStatement(statements[i]));
      }
    }
    explanation.fullyExplained = true;
    for (Reason reason : explanation.reasons) {
      explanation.fullyExplained &= reason.code != UNEXPLAINED_CHANGE;
    }
    explanation.setOutcome(
      StewardOutcome.COMPLETED,
      explanation.fullyExplained ? null : UNEXPLAINED_CHANGE
    );
  }

  private static Boolean isUnpaid(Billing_Statement__c statement) {
    return zeroIfNull(statement.Balance__c) > 0 &&
      statement.Status__c != STATEMENT_WRITTEN_OFF;
  }

  private static Reason postedCredit(Adjustment__c credit) {
    Reason reason = new Reason();
    reason.code = POSTED_CREDIT;
    reason.amount = credit.Amount__c;
    reason.creditType = credit.Type__c;
    reason.postedDate = credit.Posted_Date__c;
    return reason;
  }

  private static Reason unpaidStatement(Billing_Statement__c statement) {
    Reason reason = new Reason();
    reason.code = UNPAID_PRIOR_STATEMENT;
    reason.amount = statement.Balance__c;
    reason.statementId = statement.Id;
    reason.statementNumber = statement.Name;
    reason.statementDate = statement.Statement_Date__c;
    reason.dueDate = statement.Due_Date__c;
    reason.statementStatus = statement.Status__c;
    return reason;
  }

  private static StatementSummary summarize(Billing_Statement__c statement) {
    StatementSummary summary = new StatementSummary();
    summary.statementId = statement.Id;
    summary.statementNumber = statement.Name;
    summary.statementDate = statement.Statement_Date__c;
    summary.dueDate = statement.Due_Date__c;
    summary.amountDue = zeroIfNull(statement.Amount_Due__c);
    summary.amountPaid = zeroIfNull(statement.Amount_Paid__c);
    summary.creditsApplied = zeroIfNull(statement.Credits_Applied__c);
    summary.balance = zeroIfNull(statement.Balance__c);
    summary.status = statement.Status__c;
    return summary;
  }

  private static Decimal zeroIfNull(Decimal value) {
    return value == null ? 0 : value;
  }

  // The statements and posted credits of every household in the batch the caller can see, read
  // once in user mode.
  private with sharing class HouseholdRecords {
    private Set<Id> visible;
    private Map<Id, List<Billing_Statement__c>> statementsByAccount = new Map<Id, List<Billing_Statement__c>>();
    private Map<Id, List<Adjustment__c>> creditsByStatement = new Map<Id, List<Adjustment__c>>();

    /**
     * Reads the records for every household in the batch.
     * @param requests the batch
     */
    public HouseholdRecords(List<Request> requests) {
      Set<Id> accountIds = new Set<Id>();
      for (Request request : requests) {
        if (request != null) {
          accountIds.add(request.accountId);
        }
      }
      visible = HouseholdScope.visibleHouseholds(accountIds);
      if (!visible.isEmpty()) {
        loadStatements();
        loadPostedCredits();
      }
    }

    private void loadStatements() {
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
          Service_Contract__r.Escalator_Rate__c,
          Service_Contract__r.First_Due_Date__c,
          Service_Contract__r.StartDate
        FROM Billing_Statement__c
        WHERE Account__c IN :visible
        WITH USER_MODE
        ORDER BY Statement_Date__c DESC, Name DESC
      ]) {
        if (!statementsByAccount.containsKey(statement.Account__c)) {
          statementsByAccount.put(
            statement.Account__c,
            new List<Billing_Statement__c>()
          );
        }
        statementsByAccount.get(statement.Account__c).add(statement);
      }
    }

    private void loadPostedCredits() {
      for (Adjustment__c credit : [
        SELECT Id, Billing_Statement__c, Type__c, Amount__c, Posted_Date__c
        FROM Adjustment__c
        WHERE
          Account__c IN :visible
          AND Billing_Statement__c != NULL
          AND Status__c = :CREDIT_POSTED
        WITH USER_MODE
        ORDER BY Posted_Date__c ASC, Name ASC
      ]) {
        if (!creditsByStatement.containsKey(credit.Billing_Statement__c)) {
          creditsByStatement.put(
            credit.Billing_Statement__c,
            new List<Adjustment__c>()
          );
        }
        creditsByStatement.get(credit.Billing_Statement__c).add(credit);
      }
    }

    /**
     * A household's statements.
     * @param accountId the household
     * @return newest first; empty for a household out of reach or without statements
     */
    public List<Billing_Statement__c> statementsOf(Id accountId) {
      List<Billing_Statement__c> statements = statementsByAccount.get(
        accountId
      );
      return statements == null ? new List<Billing_Statement__c>() : statements;
    }

    /**
     * Where the requested statement sits in its household's list.
     * @param request the request, with an account
     * @return 0 for the latest, its position when named, or -1 when it's out of reach
     */
    public Integer indexOf(Request request) {
      if (!visible.contains(request.accountId)) {
        return -1;
      }
      if (request.statementId == null) {
        return 0;
      }
      List<Billing_Statement__c> statements = statementsOf(request.accountId);
      for (Integer i = 0; i < statements.size(); i++) {
        if (statements[i].Id == request.statementId) {
          return i;
        }
      }
      return -1;
    }

    /**
     * The posted credits on a statement. Draft, Pending Approval and Rejected never appear (ST-03).
     * @param statementId the statement
     * @return its posted credits, oldest first
     */
    public List<Adjustment__c> postedCreditsOn(Id statementId) {
      List<Adjustment__c> credits = creditsByStatement.get(statementId);
      return credits == null ? new List<Adjustment__c>() : credits;
    }
  }
}
