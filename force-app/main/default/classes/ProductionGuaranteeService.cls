/**
 * ST-14, S-29. The production guarantee: each household's system should produce at least
 * Production_Guarantee_Pct of its agreement's estimated annual production. measure compares the
 * last 12 complete months of readings with that guarantee. review opens a Production Review for
 * every household short of it, with a Draft Production Guarantee credit for the shortfall, which
 * goes through Accord's credit approval like any other credit.
 *
 * Readings come from a Readings source. Data 360's calculated insight is the source in the org
 * once Data 360 is set up (S-29); until then there are none, and nothing is reviewed. Tests supply
 * known readings. Agreements, statements and existing reviews are read with the caller's own
 * access, and reviews and credits are saved the same way.
 */
public with sharing class ProductionGuaranteeService {
  /** Adjustment__c.Type__c for a production guarantee credit. */
  public static final String CREDIT_TYPE = 'Production Guarantee';
  /** Adjustment__c.Status__c for a credit nobody has reviewed yet. */
  public static final String DRAFT = 'Draft';
  /** The guarantee is measured over this many complete months. */
  public static final Integer WINDOW_MONTHS = 12;
  /** The agreement records no estimated production, so there's nothing to measure against. */
  public static final String NO_ESTIMATE = 'NO_ESTIMATE';
  /** Fewer than 12 months have readings, so the year isn't complete. */
  public static final String NOT_ENOUGH_READINGS = 'NOT_ENOUGH_READINGS';
  /** The household produced at least its guarantee. */
  public static final String GUARANTEE_MET = 'GUARANTEE_MET';
  /** The household produced less than its guarantee. */
  public static final String SHORTFALL = 'SHORTFALL';

  /** The source in use. Until Data 360 is set up there are no readings (S-29). */
  @TestVisible
  private static Readings source = new NoReadingsYet();

  private static final Set<String> OPEN_STATEMENT_STATUSES = new Set<String>{
    'Open',
    'Past Due',
    'In Dispute'
  };

  /** Where production readings come from. */
  public interface Readings {
    /**
     * Each agreement's production over the window, a month at a time added up.
     * @param agreementIds the agreements
     * @param firstMonth the first day of the window's first month
     * @param lastMonth the first day of the window's last month
     * @return each agreement's total and how many months had readings; none for no readings
     */
    Map<Id, Production> totals(
      Set<Id> agreementIds,
      Date firstMonth,
      Date lastMonth
    );
  }

  /** One agreement's production over a window. */
  public class Production {
    /** Months in the window with a reading. */
    public Integer months = 0;
    /** Total kWh over those months. */
    public Decimal kWh = 0;
  }

  /** One household's last 12 complete months, measured against its guarantee. */
  public class Measurement extends StewardOutcome.Result {
    @AuraEnabled
    public Id householdId;
    @AuraEnabled
    public Id agreementId;
    /** The first day of the window. */
    @AuraEnabled
    public Date periodStart;
    /** The last day of the window: the end of last month. */
    @AuraEnabled
    public Date periodEnd;
    @AuraEnabled
    public Integer monthsOfReadings = 0;
    @AuraEnabled
    public Decimal actualKwh;
    @AuraEnabled
    public Decimal estimatedKwh;
    /** The estimate times Production_Guarantee_Pct, rounded down to a whole kWh. */
    @AuraEnabled
    public Decimal guaranteedKwh;
    /** How far short of the guarantee, or 0. */
    @AuraEnabled
    public Decimal shortfallKwh = 0;
    /** A year's payments over the estimated production: what the customer pays per kWh. */
    public Decimal ratePerKwh;
    /** The shortfall at that rate, to the cent. */
    public Decimal creditAmount = 0;
  }

  /** What a review run did. */
  public class ReviewRun {
    /** Households measured. */
    public Integer measured = 0;
    /** New Production Reviews, each with a Draft credit. */
    public Integer opened = 0;
    /** Households short of the guarantee that already had a review for this period. */
    public Integer alreadyReviewed = 0;
  }

  /**
   * Each household's last 12 complete months before today, against its guarantee. A household the
   * caller can't see, or with no agreement, is left out.
   * @param householdIds the households
   * @param asOf the day the measure is taken; the window ends with the month before
   * @return each household's measure, by household
   */
  public static Map<Id, Measurement> measure(Set<Id> householdIds, Date asOf) {
    Date lastMonth = asOf.toStartOfMonth().addMonths(-1);
    Date firstMonth = lastMonth.addMonths(1 - WINDOW_MONTHS);
    Decimal guaranteePct = PolicySettings.getNumber(
      PolicySettings.PRODUCTION_GUARANTEE_PCT
    );
    Map<Id, ServiceContract> agreements = agreementsOf(
      HouseholdScope.visibleHouseholds(householdIds)
    );
    Map<Id, Production> totals = source.totals(
      new Map<Id, ServiceContract>(agreements.values()).keySet(),
      firstMonth,
      lastMonth
    );
    Map<Id, Measurement> measures = new Map<Id, Measurement>();
    for (Id householdId : agreements.keySet()) {
      ServiceContract agreement = agreements.get(householdId);
      Measurement result = new Measurement();
      result.householdId = householdId;
      result.agreementId = agreement.Id;
      result.periodStart = firstMonth;
      result.periodEnd = lastMonth.addMonths(1).addDays(-1);
      result.estimatedKwh = agreement.Est_Annual_Production_kWh__c;
      result.guaranteedKwh = guaranteed(result.estimatedKwh, guaranteePct);
      compare(result, agreement, totals.get(agreement.Id));
      measures.put(householdId, result);
    }
    return measures;
  }

  /**
   * Opens a Production Review, with a Draft Production Guarantee credit, for every household short
   * of its guarantee over the last 12 complete months. A household reviewed for the same period
   * already is left alone, so running the review twice opens nothing new.
   * @param householdIds the households to review
   * @param asOf the day the review runs
   * @return what was measured, opened and found already reviewed
   */
  public static ReviewRun review(Set<Id> householdIds, Date asOf) {
    ReviewRun run = new ReviewRun();
    List<Measurement> shortOfGuarantee = new List<Measurement>();
    for (Measurement result : measure(householdIds, asOf).values()) {
      run.measured++;
      if (result.reasonCode == SHORTFALL) {
        shortOfGuarantee.add(result);
      }
    }
    if (shortOfGuarantee.isEmpty()) {
      return run;
    }
    Set<String> reviewed = reviewedKeys(shortOfGuarantee);
    List<Measurement> toOpen = new List<Measurement>();
    for (Measurement result : shortOfGuarantee) {
      if (reviewed.contains(keyOf(result))) {
        run.alreadyReviewed++;
      } else {
        toOpen.add(result);
      }
    }
    run.opened = open(toOpen);
    return run;
  }

  /**
   * The key that makes one review per agreement and period: the agreement and the window's last
   * month.
   * @param result the measure
   * @return the key, such as 810000000000001AAA-2026-10
   */
  @TestVisible
  private static String keyOf(Measurement result) {
    return result.agreementId +
      '-' +
      String.valueOf(result.periodEnd.year()) +
      '-' +
      String.valueOf(result.periodEnd.month()).leftPad(2, '0');
  }

  /**
   * The guarantee: the estimate times the policy's share, rounded down to a whole kWh.
   * @param estimatedKwh the agreement's estimated annual production
   * @param guaranteePct Production_Guarantee_Pct
   * @return the guaranteed kWh, or null with no estimate
   */
  private static Decimal guaranteed(
    Decimal estimatedKwh,
    Decimal guaranteePct
  ) {
    return estimatedKwh == null ||
      estimatedKwh <= 0
      ? null
      : (estimatedKwh *
          guaranteePct /
          100)
          .setScale(0, System.RoundingMode.DOWN);
  }

  /**
   * Measures one household's readings against its guarantee, already on the result.
   * @param result the measure so far: the period, the estimate and the guarantee
   * @param agreement the agreement, for its monthly payment
   * @param production the readings over the period, or null for none
   */
  private static void compare(
    Measurement result,
    ServiceContract agreement,
    Production production
  ) {
    result.monthsOfReadings = production == null ? 0 : production.months;
    result.actualKwh = production == null ? 0 : production.kWh;
    if (result.guaranteedKwh == null) {
      result.setOutcome(StewardOutcome.DECLINED_POLICY, NO_ESTIMATE);
      return;
    }
    if (result.monthsOfReadings < WINDOW_MONTHS) {
      result.setOutcome(StewardOutcome.DECLINED_POLICY, NOT_ENOUGH_READINGS);
      return;
    }
    if (result.actualKwh >= result.guaranteedKwh) {
      result.setOutcome(StewardOutcome.COMPLETED, GUARANTEE_MET);
      return;
    }
    result.shortfallKwh = result.guaranteedKwh - result.actualKwh;
    result.ratePerKwh = agreement.Monthly_Payment__c == null
      ? 0
      : (agreement.Monthly_Payment__c *
          WINDOW_MONTHS /
          result.estimatedKwh)
          .setScale(4, System.RoundingMode.HALF_UP);
    result.creditAmount = (result.shortfallKwh * result.ratePerKwh)
      .setScale(2, System.RoundingMode.HALF_UP);
    result.setOutcome(StewardOutcome.COMPLETED, SHORTFALL);
  }

  /**
   * Each household's agreement: its newest one, by start date.
   * @param householdIds households the caller can see
   * @return the agreement, by household
   */
  private static Map<Id, ServiceContract> agreementsOf(Set<Id> householdIds) {
    Map<Id, ServiceContract> byHousehold = new Map<Id, ServiceContract>();
    for (ServiceContract agreement : [
      SELECT
        Id,
        AccountId,
        Est_Annual_Production_kWh__c,
        Monthly_Payment__c,
        StartDate
      FROM ServiceContract
      WHERE AccountId IN :householdIds
      WITH USER_MODE
      ORDER BY AccountId, StartDate DESC NULLS LAST, Id
    ]) {
      if (!byHousehold.containsKey(agreement.AccountId)) {
        byHousehold.put(agreement.AccountId, agreement);
      }
    }
    return byHousehold;
  }

  private static Set<String> reviewedKeys(List<Measurement> measures) {
    Set<String> keys = new Set<String>();
    for (Measurement result : measures) {
      keys.add(keyOf(result));
    }
    Set<String> reviewed = new Set<String>();
    for (Production_Review__c existing : [
      SELECT Review_Key__c
      FROM Production_Review__c
      WHERE Review_Key__c IN :keys
      WITH USER_MODE
    ]) {
      reviewed.add(existing.Review_Key__c);
    }
    return reviewed;
  }

  /**
   * Saves a Draft credit and a Production Review for each measure, and links them. A shortfall
   * worth nothing at the agreement's rate, such as one with no monthly payment recorded, gets a
   * review without a credit, for a specialist to work out.
   * @param measures households short of the guarantee, not yet reviewed for the period
   * @return how many reviews were opened
   */
  private static Integer open(List<Measurement> measures) {
    if (measures.isEmpty()) {
      return 0;
    }
    Map<Id, Id> statements = statementToCredit(householdsOf(measures));
    Map<Id, Adjustment__c> credits = new Map<Id, Adjustment__c>();
    for (Measurement result : measures) {
      if (result.creditAmount > 0) {
        credits.put(
          result.householdId,
          new Adjustment__c(
            Account__c = result.householdId,
            Billing_Statement__c = statements.get(result.householdId),
            Type__c = CREDIT_TYPE,
            Status__c = DRAFT,
            Amount__c = result.creditAmount
          )
        );
      }
    }
    Database.insert(credits.values(), AccessLevel.USER_MODE);
    List<Production_Review__c> reviews = new List<Production_Review__c>();
    for (Measurement result : measures) {
      reviews.add(toReview(result, credits.get(result.householdId)?.Id));
    }
    Database.insert(reviews, AccessLevel.USER_MODE);
    return reviews.size();
  }

  private static Production_Review__c toReview(
    Measurement result,
    Id creditId
  ) {
    return new Production_Review__c(
      Account__c = result.householdId,
      Agreement__c = result.agreementId,
      Period_Start__c = result.periodStart,
      Period_End__c = result.periodEnd,
      Months_of_Readings__c = result.monthsOfReadings,
      Actual_kWh__c = result.actualKwh,
      Estimated_kWh__c = result.estimatedKwh,
      Guaranteed_kWh__c = result.guaranteedKwh,
      Shortfall_kWh__c = result.shortfallKwh,
      Rate_per_kWh__c = result.ratePerKwh,
      Credit_Amount__c = result.creditAmount,
      Adjustment__c = creditId,
      Review_Key__c = keyOf(result)
    );
  }

  private static Set<Id> householdsOf(List<Measurement> measures) {
    Set<Id> households = new Set<Id>();
    for (Measurement result : measures) {
      households.add(result.householdId);
    }
    return households;
  }

  /**
   * The statement each household's credit applies to: its newest one still open, past due or in
   * dispute. A household with none gets a credit with no statement, for a specialist to place.
   * @param householdIds the households
   * @return the statement, by household
   */
  private static Map<Id, Id> statementToCredit(Set<Id> householdIds) {
    Map<Id, Id> byHousehold = new Map<Id, Id>();
    for (Billing_Statement__c statement : [
      SELECT Id, Account__c
      FROM Billing_Statement__c
      WHERE
        Account__c IN :householdIds
        AND Status__c IN :OPEN_STATEMENT_STATUSES
      WITH USER_MODE
      ORDER BY Account__c, Due_Date__c DESC NULLS LAST, Id
    ]) {
      if (!byHousehold.containsKey(statement.Account__c)) {
        byHousehold.put(statement.Account__c, statement.Id);
      }
    }
    return byHousehold;
  }

  /** No readings at all, until Data 360 is set up (S-29). */
  private class NoReadingsYet implements Readings {
    /**
     * No agreement has readings yet.
     * @param agreementIds the agreements
     * @param firstMonth the window's first month
     * @param lastMonth the window's last month
     * @return an empty map
     */
    public Map<Id, Production> totals(
      Set<Id> agreementIds,
      Date firstMonth,
      Date lastMonth
    ) {
      return new Map<Id, Production>();
    }
  }
}
