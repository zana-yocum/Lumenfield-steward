/**
 * ST-03, ST-12, GR-04. Known-answer tests for the statement explanation. The escalator household
 * pays $120.00 until its agreement's first anniversary, then $123.48 (2.90%). Its latest statement
 * also carries a posted $40 goodwill credit, plus a draft, a pending and a rejected credit that
 * must never be mentioned, and an earlier statement is still unpaid. Other households cover an
 * unexplained change, no change, a first statement, no statements, and an increase that matches
 * the rate but not the anniversary. Includes the 200-household bulk test (NFR-02).
 */
@IsTest
private class StatementExplanationServiceTest {
  private static final Integer ESCALATOR = 0;
  private static final Integer UNEXPLAINED = 1;
  private static final Integer UNCHANGED = 2;
  private static final Integer FIRST = 3;
  private static final Integer EMPTY = 4;
  private static final Integer OFF_ANNIVERSARY = 5;

  @TestSetup
  static void createData() {
    List<StewardTestData.Household> households = StewardTestData.createHouseholds(
      6,
      StewardTestData.ACCOUNT_DELINQUENT
    );
    Date anniversary = StewardTestData.firstAnniversary();
    StewardTestData.Household escalated = households[ESCALATOR];

    List<Billing_Statement__c> statements = new List<Billing_Statement__c>{
      // 0-2: the escalator household
      StewardTestData.statement(
        escalated,
        anniversary.addMonths(-2),
        120.00,
        StewardTestData.STATEMENT_PAID
      ),
      StewardTestData.statement(
        escalated,
        anniversary.addMonths(-1),
        120.00,
        StewardTestData.STATEMENT_PAST_DUE
      ),
      StewardTestData.statement(
        escalated,
        anniversary,
        123.48,
        StewardTestData.STATEMENT_PAST_DUE
      ),
      // 3-4: up $15 with no anniversary in between
      StewardTestData.statement(
        households[UNEXPLAINED],
        StewardTestData.monthStart(4),
        120.00,
        StewardTestData.STATEMENT_PAID
      ),
      StewardTestData.statement(
        households[UNEXPLAINED],
        StewardTestData.monthStart(3),
        135.00,
        StewardTestData.STATEMENT_PAST_DUE
      ),
      // 5-6: no change
      StewardTestData.statement(
        households[UNCHANGED],
        StewardTestData.monthStart(3),
        120.00,
        StewardTestData.STATEMENT_PAID
      ),
      StewardTestData.statement(
        households[UNCHANGED],
        StewardTestData.monthStart(2),
        120.00,
        StewardTestData.STATEMENT_PAST_DUE
      ),
      // 7: a first statement
      StewardTestData.statement(
        households[FIRST],
        StewardTestData.monthStart(1),
        120.00,
        StewardTestData.STATEMENT_PAST_DUE
      ),
      // 8-9: up by exactly the rate, but months before the anniversary
      StewardTestData.statement(
        households[OFF_ANNIVERSARY],
        StewardTestData.monthStart(4),
        120.00,
        StewardTestData.STATEMENT_PAID
      ),
      StewardTestData.statement(
        households[OFF_ANNIVERSARY],
        StewardTestData.monthStart(3),
        123.48,
        StewardTestData.STATEMENT_PAST_DUE
      )
    };
    insert statements;
    insert new List<Payment__c>{
      StewardTestData.payment(statements[0], 120.00, anniversary.addMonths(-2)),
      StewardTestData.payment(
        statements[3],
        120.00,
        StewardTestData.monthStart(4)
      ),
      StewardTestData.payment(
        statements[5],
        120.00,
        StewardTestData.monthStart(3)
      ),
      StewardTestData.payment(
        statements[8],
        120.00,
        StewardTestData.monthStart(4)
      )
    };

    // One credit per save, the way reps create them: Accord's flow recalculates the statement
    // each time. Amounts above the rep limit keep the draft and pending credits from auto-posting.
    Decimal repLimit = StewardTestData.policyNumber('Rep_Credit_Limit');
    Billing_Statement__c latest = statements[2];
    insert StewardTestData.credit(latest, 40.00, 'Goodwill Credit', 'Posted');
    insert StewardTestData.credit(
      latest,
      repLimit + 50,
      'Billing Correction',
      'Draft'
    );
    insert StewardTestData.credit(
      latest,
      repLimit + 100,
      'Production Guarantee',
      'Pending Approval'
    );
    insert StewardTestData.credit(latest, 60.00, 'Goodwill Credit', 'Rejected');
  }

  private static List<Account> households() {
    return [
      SELECT Id
      FROM Account
      WHERE Name LIKE 'Steward Test Household%'
      ORDER BY Name
    ];
  }

  @IsTest
  static void explainsTheEscalatorAtTheAnniversary() {
    Id householdId = households()[ESCALATOR].Id;

    Test.startTest();
    StatementExplanationService.Explanation explanation = StatementExplanationService.explain(
      householdId,
      null
    );
    Test.stopTest();

    Assert.areEqual(StewardOutcome.COMPLETED, explanation.outcome, 'Completed');
    Assert.isTrue(explanation.fullyExplained, 'Fully explained');
    StatementExplanationService.Reason change = explanation.reasons[0];
    Assert.areEqual(
      StatementExplanationService.ESCALATOR,
      change.code,
      'The escalator explains the increase'
    );
    Assert.areEqual(3.48, change.amount, 'Increase');
    Assert.areEqual(120.00, change.amountBefore, 'Before');
    Assert.areEqual(123.48, change.amountAfter, 'After');
    Assert.areEqual(
      StewardTestData.ESCALATOR_RATE_PCT,
      change.escalatorRatePct,
      'The rate in the agreement'
    );
    Assert.areEqual(
      StewardTestData.firstAnniversary(),
      change.anniversaryDate,
      'At the agreement anniversary'
    );
    Assert.areEqual(
      StewardTestData.firstAnniversary(),
      explanation.statement.dueDate,
      'The latest statement is explained'
    );
    Assert.areEqual(
      120.00,
      explanation.priorStatement.amountDue,
      'Compared with the one before'
    );
  }

  @IsTest
  static void namesPostedCreditsAndNeverTheOthers() {
    Test.startTest();
    StatementExplanationService.Explanation explanation = StatementExplanationService.explain(
      households()[ESCALATOR].Id,
      null
    );
    Test.stopTest();

    List<StatementExplanationService.Reason> credits = reasonsWithCode(
      explanation,
      StatementExplanationService.POSTED_CREDIT
    );
    Assert.areEqual(1, credits.size(), 'Only the posted credit is mentioned');
    Assert.areEqual(40.00, credits[0].amount, 'Credit amount');
    Assert.areEqual('Goodwill Credit', credits[0].creditType, 'Credit type');
    Assert.areEqual(Date.today(), credits[0].postedDate, 'When it posted');
    Assert.areEqual(
      40.00,
      explanation.statement.creditsApplied,
      'Accord applied only the posted credit to the statement'
    );
    Assert.areEqual(
      83.48,
      explanation.statement.balance,
      'Balance after the credit'
    );
  }

  @IsTest
  static void listsUnpaidEarlierStatements() {
    Test.startTest();
    StatementExplanationService.Explanation explanation = StatementExplanationService.explain(
      households()[ESCALATOR].Id,
      null
    );
    Test.stopTest();

    List<StatementExplanationService.Reason> unpaid = reasonsWithCode(
      explanation,
      StatementExplanationService.UNPAID_PRIOR_STATEMENT
    );
    Assert.areEqual(
      1,
      unpaid.size(),
      'The paid statement is left out; the unpaid one is listed'
    );
    Assert.areEqual(120.00, unpaid[0].amount, 'Its balance');
    Assert.areEqual(
      StewardTestData.firstAnniversary().addMonths(-1),
      unpaid[0].dueDate,
      'Its due date'
    );
    Assert.areEqual(
      StewardTestData.STATEMENT_PAST_DUE,
      unpaid[0].statementStatus,
      'Its status'
    );
  }

  @IsTest
  static void saysWhenTheRecordsDoNotExplainAChange() {
    List<Account> accounts = households();

    Test.startTest();
    List<StatementExplanationService.Explanation> explanations = StatementExplanationService.explain(
      new List<StatementExplanationService.Request>{
        new StatementExplanationService.Request(accounts[UNEXPLAINED].Id, null),
        new StatementExplanationService.Request(
          accounts[OFF_ANNIVERSARY].Id,
          null
        )
      }
    );
    Test.stopTest();

    StatementExplanationService.Explanation notExplained = explanations[0];
    Assert.isFalse(notExplained.fullyExplained, 'Not explained');
    Assert.areEqual(
      StatementExplanationService.UNEXPLAINED_CHANGE,
      notExplained.reasonCode,
      'Says it can\'t explain it'
    );
    Assert.areEqual(
      15.00,
      notExplained.reasons[0].amount,
      'The unexplained difference'
    );
    Assert.areEqual(
      StatementExplanationService.UNEXPLAINED_CHANGE,
      explanations[1].reasons[0].code,
      'A rate-sized increase away from the anniversary isn\'t called an escalator'
    );
  }

  @IsTest
  static void reportsNoChangeFirstStatementAndNoStatements() {
    List<Account> accounts = households();

    Test.startTest();
    List<StatementExplanationService.Explanation> explanations = StatementExplanationService.explain(
      new List<StatementExplanationService.Request>{
        new StatementExplanationService.Request(accounts[UNCHANGED].Id, null),
        new StatementExplanationService.Request(accounts[FIRST].Id, null),
        new StatementExplanationService.Request(accounts[EMPTY].Id, null)
      }
    );
    Test.stopTest();

    Assert.areEqual(
      StatementExplanationService.NO_CHANGE,
      explanations[0].reasons[0].code,
      'Same amount as before'
    );
    Assert.areEqual(0.00, explanations[0].reasons[0].amount, 'No difference');
    Assert.areEqual(
      StatementExplanationService.FIRST_STATEMENT,
      explanations[1].reasons[0].code,
      'Nothing to compare with'
    );
    Assert.areEqual(
      StatementExplanationService.NO_STATEMENTS,
      explanations[2].reasonCode,
      'No statements yet'
    );
    Assert.isTrue(explanations[2].reasons.isEmpty(), 'No reasons');
  }

  @IsTest
  static void explainsAChosenEarlierStatement() {
    Id householdId = households()[ESCALATOR].Id;
    Billing_Statement__c earlier = [
      SELECT Id
      FROM Billing_Statement__c
      WHERE
        Account__c = :householdId
        AND Due_Date__c = :StewardTestData.firstAnniversary().addMonths(-1)
    ];

    Test.startTest();
    StatementExplanationService.Explanation explanation = StatementExplanationService.explain(
      householdId,
      earlier.Id
    );
    Test.stopTest();

    Assert.areEqual(
      earlier.Id,
      explanation.statement.statementId,
      'The chosen statement'
    );
    Assert.areEqual(1, explanation.reasons.size(), 'Only the comparison');
    Assert.areEqual(
      StatementExplanationService.NO_CHANGE,
      explanation.reasons[0].code,
      'Same as the paid one before it'
    );
  }

  @IsTest
  static void anotherHouseholdsStatementIsNotFound() {
    List<Account> accounts = households();
    Billing_Statement__c someoneElses = [
      SELECT Id
      FROM Billing_Statement__c
      WHERE Account__c = :accounts[UNEXPLAINED].Id
      LIMIT 1
    ];
    User outsider = StewardTestData.createUserWithoutAccess();

    StatementExplanationService.Explanation asOutsider;
    Test.startTest();
    StatementExplanationService.Explanation crossHousehold = StatementExplanationService.explain(
      accounts[ESCALATOR].Id,
      someoneElses.Id
    );
    StatementExplanationService.Explanation noStatements = StatementExplanationService.explain(
      accounts[EMPTY].Id,
      someoneElses.Id
    );
    System.runAs(outsider) {
      asOutsider = StatementExplanationService.explain(
        accounts[ESCALATOR].Id,
        null
      );
    }
    StatementExplanationService.Explanation noAccount = StatementExplanationService.explain(
      null,
      null
    );
    Test.stopTest();

    Assert.areEqual(
      StewardOutcome.NOT_FOUND,
      crossHousehold.reasonCode,
      'A statement from another household is not found'
    );
    Assert.isNull(crossHousehold.statement, 'Nothing about it is returned');
    Assert.areEqual(
      StewardOutcome.NOT_FOUND,
      noStatements.reasonCode,
      'Not found, even for a household with no statements'
    );
    Assert.areEqual(
      StewardOutcome.NOT_FOUND,
      asOutsider.reasonCode,
      'A household the caller can\'t see is not found'
    );
    Assert.areEqual(
      StewardOutcome.INVALID_REQUEST,
      noAccount.reasonCode,
      'No account, no explanation'
    );
    Assert.isTrue(
      StatementExplanationService.explain(
          (List<StatementExplanationService.Request>) null
        )
        .isEmpty(),
      'A null list gives nothing'
    );
  }

  @IsTest
  static void explains200HouseholdsWithThreeQueries() {
    List<StewardTestData.Household> many = StewardTestData.createHouseholds(
      200,
      StewardTestData.ACCOUNT_DELINQUENT
    );
    List<Billing_Statement__c> statements = new List<Billing_Statement__c>();
    List<StatementExplanationService.Request> requests = new List<StatementExplanationService.Request>();
    for (StewardTestData.Household household : many) {
      statements.add(
        StewardTestData.statement(
          household,
          StewardTestData.monthStart(3),
          120.00,
          StewardTestData.STATEMENT_PAST_DUE
        )
      );
      statements.add(
        StewardTestData.statement(
          household,
          StewardTestData.monthStart(2),
          120.00,
          StewardTestData.STATEMENT_PAST_DUE
        )
      );
      requests.add(
        new StatementExplanationService.Request(household.account.Id, null)
      );
    }
    insert statements;

    Test.startTest();
    List<StatementExplanationService.Explanation> explanations = StatementExplanationService.explain(
      requests
    );
    Integer queries = Limits.getQueries();
    Test.stopTest();

    Assert.areEqual(200, explanations.size(), 'One explanation each');
    Assert.isTrue(queries <= 3, 'Three queries at most, used ' + queries);
    for (StatementExplanationService.Explanation explanation : explanations) {
      Assert.areEqual(
        StatementExplanationService.NO_CHANGE,
        explanation.reasons[0].code,
        'Same amount'
      );
      Assert.areEqual(
        StatementExplanationService.UNPAID_PRIOR_STATEMENT,
        explanation.reasons[1].code,
        'The earlier statement is unpaid'
      );
    }
  }

  private static List<StatementExplanationService.Reason> reasonsWithCode(
    StatementExplanationService.Explanation explanation,
    String code
  ) {
    List<StatementExplanationService.Reason> matching = new List<StatementExplanationService.Reason>();
    for (StatementExplanationService.Reason reason : explanation.reasons) {
      if (reason.code == code) {
        matching.add(reason);
      }
    }
    return matching;
  }
}
