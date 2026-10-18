/**
 * ST-03, GR-04. Edge cases for the escalator rule, on statements built in memory: the first and a
 * later anniversary, rounding to the cent, a rate-sized increase away from the anniversary, a
 * wrong-sized increase at it, decreases, missing agreements and missing dates, and leap days.
 */
@IsTest
private class AmountDueComparisonTest {
  private static final Decimal RATE_PCT = 2.90;

  private static ServiceContract agreement(Date firstDue) {
    return new ServiceContract(
      Escalator_Rate__c = RATE_PCT,
      First_Due_Date__c = firstDue,
      StartDate = firstDue == null ? null : firstDue.addMonths(-1)
    );
  }

  private static Billing_Statement__c statement(
    Decimal amountDue,
    Date dueDate,
    ServiceContract onAgreement
  ) {
    return new Billing_Statement__c(
      Amount_Due__c = amountDue,
      Due_Date__c = dueDate,
      Statement_Date__c = dueDate?.addDays(-20),
      Service_Contract__r = onAgreement
    );
  }

  @IsTest
  static void anIncreaseByTheRateAtTheAnniversaryIsTheEscalator() {
    ServiceContract lease = agreement(Date.newInstance(2025, 3, 1));

    StatementExplanationService.Reason reason = AmountDueComparison.compare(
      statement(123.48, Date.newInstance(2026, 3, 1), lease),
      statement(120.00, Date.newInstance(2026, 2, 1), lease)
    );

    Assert.areEqual(
      StatementExplanationService.ESCALATOR,
      reason.code,
      'The escalator'
    );
    Assert.areEqual(3.48, reason.amount, 'The increase');
    Assert.areEqual(120.00, reason.amountBefore, 'Before');
    Assert.areEqual(123.48, reason.amountAfter, 'After');
    Assert.areEqual(RATE_PCT, reason.escalatorRatePct, 'The rate');
    Assert.areEqual(
      Date.newInstance(2026, 3, 1),
      reason.anniversaryDate,
      'At the first anniversary'
    );
  }

  @IsTest
  static void aLaterAnniversaryCompoundsAndRoundsToTheCent() {
    ServiceContract lease = agreement(Date.newInstance(2025, 3, 1));

    // $123.48 x 1.029 = $127.06092, billed as $127.06.
    StatementExplanationService.Reason reason = AmountDueComparison.compare(
      statement(127.06, Date.newInstance(2027, 3, 1), lease),
      statement(123.48, Date.newInstance(2027, 2, 1), lease)
    );

    Assert.areEqual(
      StatementExplanationService.ESCALATOR,
      reason.code,
      'Still the escalator after rounding'
    );
    Assert.areEqual(
      Date.newInstance(2027, 3, 1),
      reason.anniversaryDate,
      'At the second anniversary'
    );
  }

  @IsTest
  static void anythingElseIsUnexplained() {
    ServiceContract lease = agreement(Date.newInstance(2025, 3, 1));
    Billing_Statement__c february = statement(
      120.00,
      Date.newInstance(2026, 2, 1),
      lease
    );

    Assert.areEqual(
      StatementExplanationService.UNEXPLAINED_CHANGE,
      AmountDueComparison.compare(
          statement(123.48, Date.newInstance(2026, 6, 1), lease),
          statement(120.00, Date.newInstance(2026, 5, 1), lease)
        )
        .code,
      'The right amount away from the anniversary'
    );
    Assert.areEqual(
      StatementExplanationService.UNEXPLAINED_CHANGE,
      AmountDueComparison.compare(
          statement(125.00, Date.newInstance(2026, 3, 1), lease),
          february
        )
        .code,
      'The wrong amount at the anniversary'
    );
    Assert.areEqual(
      StatementExplanationService.UNEXPLAINED_CHANGE,
      AmountDueComparison.compare(
          statement(100.00, Date.newInstance(2026, 3, 1), lease),
          february
        )
        .code,
      'A decrease'
    );
    Assert.areEqual(
      StatementExplanationService.UNEXPLAINED_CHANGE,
      AmountDueComparison.compare(
          statement(123.48, Date.newInstance(2026, 3, 1), null),
          statement(120.00, Date.newInstance(2026, 2, 1), null)
        )
        .code,
      'No agreement on file'
    );
  }

  @IsTest
  static void noChangeAndFirstStatement() {
    ServiceContract lease = agreement(Date.newInstance(2025, 3, 1));

    StatementExplanationService.Reason sameToTheCent = AmountDueComparison.compare(
      statement(120.01, Date.newInstance(2026, 5, 1), lease),
      statement(120.00, Date.newInstance(2026, 4, 1), lease)
    );
    StatementExplanationService.Reason first = AmountDueComparison.compare(
      statement(120.00, Date.newInstance(2026, 5, 1), lease),
      null
    );

    Assert.areEqual(
      StatementExplanationService.NO_CHANGE,
      sameToTheCent.code,
      'A cent of rounding is no change'
    );
    Assert.areEqual(0.00, sameToTheCent.amount, 'Reported as no difference');
    Assert.areEqual(
      StatementExplanationService.FIRST_STATEMENT,
      first.code,
      'Nothing to compare with'
    );
    Assert.areEqual(120.00, first.amount, 'Its own amount');
  }

  @IsTest
  static void fallsBackToTheStartDateAndTheStatementDate() {
    ServiceContract noFirstDue = new ServiceContract(
      Escalator_Rate__c = RATE_PCT,
      StartDate = Date.newInstance(2025, 3, 1)
    );
    Billing_Statement__c before = new Billing_Statement__c(
      Amount_Due__c = 120.00,
      Statement_Date__c = Date.newInstance(2026, 2, 10),
      Service_Contract__r = noFirstDue
    );
    Billing_Statement__c after = new Billing_Statement__c(
      Amount_Due__c = 123.48,
      Statement_Date__c = Date.newInstance(2026, 3, 10),
      Service_Contract__r = noFirstDue
    );

    StatementExplanationService.Reason reason = AmountDueComparison.compare(
      after,
      before
    );

    Assert.areEqual(
      StatementExplanationService.ESCALATOR,
      reason.code,
      'Agreement start and statement dates stand in for blank ones'
    );
    Assert.areEqual(
      Date.newInstance(2026, 3, 1),
      reason.anniversaryDate,
      'Anniversary of the start date'
    );
  }

  @IsTest
  static void anniversaryEdges() {
    Date basis = Date.newInstance(2024, 3, 1);

    Assert.isNull(
      AmountDueComparison.anniversaryBetween(null, basis, basis),
      'No basis, no anniversary'
    );
    Assert.areEqual(
      Date.newInstance(2026, 3, 1),
      AmountDueComparison.anniversaryBetween(
        basis,
        Date.newInstance(2026, 2, 1),
        Date.newInstance(2026, 3, 1)
      ),
      'On the later date counts'
    );
    Assert.isNull(
      AmountDueComparison.anniversaryBetween(
        basis,
        Date.newInstance(2026, 3, 1),
        Date.newInstance(2026, 4, 1)
      ),
      'On the earlier date doesn\'t count again'
    );
    Assert.areEqual(
      Date.newInstance(2028, 2, 29),
      AmountDueComparison.anniversaryBetween(
        Date.newInstance(2024, 2, 29),
        Date.newInstance(2028, 2, 1),
        Date.newInstance(2028, 3, 1)
      ),
      'A leap-day agreement keeps its day in leap years'
    );
  }

  @IsTest
  static void rateEdges() {
    Assert.isFalse(
      AmountDueComparison.matchesRate(120.00, 3.48, null),
      'No rate'
    );
    Assert.isFalse(
      AmountDueComparison.matchesRate(120.00, 3.48, 0),
      'A zero rate'
    );
    Assert.isFalse(
      AmountDueComparison.matchesRate(120.00, -3.48, RATE_PCT),
      'A decrease'
    );
    Assert.isTrue(
      AmountDueComparison.matchesRate(120.00, 3.48, RATE_PCT),
      'The step itself'
    );
  }
}
