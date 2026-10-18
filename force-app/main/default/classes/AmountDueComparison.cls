/**
 * ST-03, GR-04. Says what a change in amount due between two statements means: nothing changed,
 * the agreement's annual escalator applied at its anniversary, or a change the records don't
 * explain. An increase counts as the escalator only when both are true: it equals the earlier
 * amount times the agreement's rate, to the cent, and an agreement anniversary falls between the
 * two statements. Pure logic on records already read, so its edge cases are tested without data.
 */
public with sharing class AmountDueComparison {
  // Rounding, not policy: amounts are stored to the cent, so an escalator step computed from the
  // rate can differ from the billed one by up to a cent.
  @TestVisible
  private static final Decimal CENT_TOLERANCE = 0.01;

  /**
   * Compares a statement's amount due with the one before it.
   * @param target the statement being explained, with its Service_Contract__r rate and dates
   * @param prior the statement before it, or null
   * @return FIRST_STATEMENT, NO_CHANGE, ESCALATOR or UNEXPLAINED_CHANGE, with the figures
   */
  public static StatementExplanationService.Reason compare(
    Billing_Statement__c target,
    Billing_Statement__c prior
  ) {
    StatementExplanationService.Reason reason = new StatementExplanationService.Reason();
    reason.amountAfter = zeroIfNull(target.Amount_Due__c);
    if (prior == null) {
      reason.code = StatementExplanationService.FIRST_STATEMENT;
      reason.amount = reason.amountAfter;
      return reason;
    }
    reason.amountBefore = zeroIfNull(prior.Amount_Due__c);
    reason.amount = reason.amountAfter - reason.amountBefore;
    if (reason.amount.abs() <= CENT_TOLERANCE) {
      reason.code = StatementExplanationService.NO_CHANGE;
      reason.amount = 0;
      return reason;
    }
    Decimal ratePct = target.Service_Contract__r?.Escalator_Rate__c;
    Date anniversary = anniversaryBetween(
      basisDate(target),
      billingDate(prior),
      billingDate(target)
    );
    if (
      anniversary != null &&
      matchesRate(reason.amountBefore, reason.amount, ratePct)
    ) {
      reason.code = StatementExplanationService.ESCALATOR;
      reason.escalatorRatePct = ratePct;
      reason.anniversaryDate = anniversary;
    } else {
      reason.code = StatementExplanationService.UNEXPLAINED_CHANGE;
    }
    return reason;
  }

  /**
   * Whether an increase equals, to the cent, the earlier amount times the agreement's rate.
   * @param before the earlier amount due
   * @param change the increase
   * @param ratePct the agreement's escalator rate, in percent
   * @return true when the increase is the escalator step
   */
  @TestVisible
  private static Boolean matchesRate(
    Decimal before,
    Decimal change,
    Decimal ratePct
  ) {
    return change > 0 &&
      ratePct != null &&
      ratePct > 0 &&
      (before * ratePct / 100 - change).abs() <= CENT_TOLERANCE;
  }

  /**
   * The first anniversary of an agreement after one date and on or before another.
   * @param basis the date anniversaries count from
   * @param afterExclusive the earlier billing date
   * @param upToInclusive the later billing date
   * @return the anniversary, or null when none falls between them
   */
  @TestVisible
  private static Date anniversaryBetween(
    Date basis,
    Date afterExclusive,
    Date upToInclusive
  ) {
    if (basis == null || afterExclusive == null || upToInclusive == null) {
      return null;
    }
    Integer years = 1;
    Date anniversary = basis.addYears(years);
    while (anniversary <= afterExclusive) {
      years++;
      anniversary = basis.addYears(years);
    }
    return anniversary <= upToInclusive ? anniversary : null;
  }

  // Anniversaries count from the first payment due date, or the agreement start if that's blank.
  private static Date basisDate(Billing_Statement__c statement) {
    ServiceContract agreement = statement.Service_Contract__r;
    if (agreement == null) {
      return null;
    }
    return agreement.First_Due_Date__c != null
      ? agreement.First_Due_Date__c
      : agreement.StartDate;
  }

  private static Date billingDate(Billing_Statement__c statement) {
    return statement.Due_Date__c != null
      ? statement.Due_Date__c
      : statement.Statement_Date__c;
  }

  private static Decimal zeroIfNull(Decimal value) {
    return value == null ? 0 : value;
  }
}
