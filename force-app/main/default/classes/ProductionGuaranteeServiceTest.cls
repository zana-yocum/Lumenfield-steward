/**
 * ST-14, S-29, NFR-02. Proves the production guarantee with known readings: a household short of
 * 90% of its estimate gets one Production Review and one Draft credit for the shortfall at its
 * rate, on its newest open statement; one at or above the guarantee, one with fewer than 12
 * months of readings and one with no estimate get nothing; running the review again opens
 * nothing new; a small credit goes through Accord's credit rules like any other; nobody is
 * reviewed whose household the caller can't see; and 200 households are reviewed in one run.
 *
 * Every household pays $120.00 a month and has an estimate of 10,000 kWh a year, so it's
 * guaranteed 9,000 kWh at $0.1440 a kWh. The review runs as of 2026-11-15, so the window is
 * 2025-11-01 to 2026-10-31.
 */
@IsTest
private class ProductionGuaranteeServiceTest {
  private static final Date AS_OF = Date.newInstance(2026, 11, 15);
  private static final Decimal ESTIMATE = 10000;

  /** Readings a test sets, by agreement. */
  private class KnownReadings implements ProductionGuaranteeService.Readings {
    public Map<Id, ProductionGuaranteeService.Production> byAgreement = new Map<Id, ProductionGuaranteeService.Production>();
    public Date askedFirst;
    public Date askedLast;

    /**
     * Sets one agreement's readings for the window.
     * @param agreementId the agreement
     * @param months how many months had a reading
     * @param kWh the total over those months
     * @return these readings, to set another
     */
    public KnownReadings produced(Id agreementId, Integer months, Decimal kWh) {
      ProductionGuaranteeService.Production production = new ProductionGuaranteeService.Production();
      production.months = months;
      production.kWh = kWh;
      byAgreement.put(agreementId, production);
      return this;
    }

    /**
     * The readings set for each agreement asked about.
     * @param agreementIds the agreements
     * @param firstMonth the window's first month
     * @param lastMonth the window's last month
     * @return the readings, by agreement
     */
    public Map<Id, ProductionGuaranteeService.Production> totals(
      Set<Id> agreementIds,
      Date firstMonth,
      Date lastMonth
    ) {
      askedFirst = firstMonth;
      askedLast = lastMonth;
      Map<Id, ProductionGuaranteeService.Production> found = new Map<Id, ProductionGuaranteeService.Production>();
      for (Id agreementId : agreementIds) {
        if (byAgreement.containsKey(agreementId)) {
          found.put(agreementId, byAgreement.get(agreementId));
        }
      }
      return found;
    }
  }

  @TestSetup
  static void createData() {
    List<StewardTestData.Household> households = StewardTestData.createHouseholds(
      4,
      StewardTestData.ACCOUNT_DELINQUENT
    );
    List<ServiceContract> agreements = new List<ServiceContract>();
    List<Billing_Statement__c> statements = new List<Billing_Statement__c>();
    for (StewardTestData.Household household : households) {
      household.agreement.Est_Annual_Production_kWh__c = ESTIMATE;
      agreements.add(household.agreement);
      statements.add(
        StewardTestData.statement(
          household,
          StewardTestData.monthStart(1),
          120.00,
          StewardTestData.STATEMENT_PAST_DUE
        )
      );
      statements.add(
        StewardTestData.statement(
          household,
          StewardTestData.monthStart(3),
          120.00,
          StewardTestData.STATEMENT_PAID
        )
      );
    }
    update agreements;
    insert statements;
  }

  private static List<StewardTestData.Household> households() {
    return StewardTestData.existingHouseholds();
  }

  private static Set<Id> idsOf(List<StewardTestData.Household> households) {
    Set<Id> ids = new Set<Id>();
    for (StewardTestData.Household household : households) {
      ids.add(household.account.Id);
    }
    return ids;
  }

  private static KnownReadings readings() {
    KnownReadings known = new KnownReadings();
    ProductionGuaranteeService.source = known;
    return known;
  }

  @IsTest
  static void aHouseholdShortOfItsGuaranteeGetsOneReviewAndADraftCredit() {
    List<StewardTestData.Household> households = households();
    KnownReadings known = readings()
      .produced(households[0].agreement.Id, 12, 8000)
      .produced(households[1].agreement.Id, 12, 9000)
      .produced(households[2].agreement.Id, 11, 6000);
    households[3].agreement.Est_Annual_Production_kWh__c = null;
    update households[3].agreement;

    ProductionGuaranteeService.ReviewRun run = ProductionGuaranteeService.review(
      idsOf(households),
      AS_OF
    );

    Assert.areEqual(4, run.measured, 'Every household measured');
    Assert.areEqual(1, run.opened, 'Only the one short of its guarantee');
    Assert.areEqual(
      Date.newInstance(2025, 11, 1),
      known.askedFirst,
      'Twelve complete months'
    );
    Assert.areEqual(
      Date.newInstance(2026, 10, 1),
      known.askedLast,
      'Ending last month'
    );
    Production_Review__c review = [
      SELECT
        Account__c,
        Agreement__c,
        Period_Start__c,
        Period_End__c,
        Months_of_Readings__c,
        Actual_kWh__c,
        Estimated_kWh__c,
        Guaranteed_kWh__c,
        Shortfall_kWh__c,
        Rate_per_kWh__c,
        Credit_Amount__c,
        Review_Key__c,
        Adjustment__r.Type__c,
        Adjustment__r.Status__c,
        Adjustment__r.Amount__c,
        Adjustment__r.Account__c,
        Adjustment__r.Billing_Statement__r.Status__c
      FROM Production_Review__c
      WITH SYSTEM_MODE
    ];
    Assert.areEqual(households[0].account.Id, review.Account__c, 'Whose');
    Assert.areEqual(
      Date.newInstance(2026, 10, 31),
      review.Period_End__c,
      'To the end of last month'
    );
    Assert.areEqual(12, review.Months_of_Readings__c.intValue(), 'A full year');
    Assert.areEqual(8000, review.Actual_kWh__c.intValue(), 'What it produced');
    Assert.areEqual(9000, review.Guaranteed_kWh__c.intValue(), '90% of 10,000');
    Assert.areEqual(1000, review.Shortfall_kWh__c.intValue(), 'Short by 1,000');
    Assert.areEqual(
      0.1440,
      review.Rate_per_kWh__c,
      '$1,440 a year over 10,000'
    );
    Assert.areEqual(144.00, review.Credit_Amount__c, '1,000 kWh at $0.1440');
    Assert.areEqual(
      'Production Guarantee',
      review.Adjustment__r.Type__c,
      'A production guarantee credit'
    );
    Assert.areEqual(
      'Draft',
      review.Adjustment__r.Status__c,
      'Over the rep limit, so it waits for review'
    );
    Assert.areEqual(
      144.00,
      review.Adjustment__r.Amount__c,
      'For the shortfall'
    );
    Assert.areEqual(
      households[0].account.Id,
      review.Adjustment__r.Account__c,
      'On the household'
    );
    Assert.areEqual(
      StewardTestData.STATEMENT_PAST_DUE,
      review.Adjustment__r.Billing_Statement__r.Status__c,
      'On its newest unpaid statement, not the paid one'
    );
    Assert.isTrue(
      review.Review_Key__c.endsWith('-2026-10'),
      'Keyed by agreement and period: ' + review.Review_Key__c
    );
  }

  @IsTest
  static void runningTheReviewAgainOpensNothingNew() {
    List<StewardTestData.Household> households = households();
    readings().produced(households[0].agreement.Id, 12, 8000);

    ProductionGuaranteeService.review(idsOf(households), AS_OF);
    ProductionGuaranteeService.ReviewRun again = ProductionGuaranteeService.review(
      idsOf(households),
      AS_OF
    );

    Assert.areEqual(0, again.opened, 'Nothing new');
    Assert.areEqual(1, again.alreadyReviewed, 'Already reviewed this period');
    Assert.areEqual(
      1,
      [SELECT COUNT() FROM Production_Review__c WITH SYSTEM_MODE],
      'One review'
    );
    Assert.areEqual(
      1,
      [
        SELECT COUNT()
        FROM Adjustment__c
        WHERE Type__c = 'Production Guarantee'
        WITH SYSTEM_MODE
      ],
      'One credit'
    );
  }

  @IsTest
  static void aSmallCreditGoesThroughAccordsRulesLikeAnyOther() {
    List<StewardTestData.Household> households = households();
    // 300 kWh short at $0.1440 is $43.20, under Accord's Rep_Credit_Limit of $100.
    readings().produced(households[0].agreement.Id, 12, 8700);

    ProductionGuaranteeService.review(idsOf(households), AS_OF);

    Adjustment__c credit = [
      SELECT Amount__c, Status__c
      FROM Adjustment__c
      WHERE Type__c = 'Production Guarantee'
      WITH SYSTEM_MODE
    ];
    Assert.areEqual(43.20, credit.Amount__c, '300 kWh at $0.1440');
    Assert.areEqual(
      'Posted',
      credit.Status__c,
      'Accord posts a credit within the rep limit at once'
    );
  }

  @IsTest
  static void eachHouseholdIsMeasuredForTheAgent() {
    List<StewardTestData.Household> households = households();
    readings()
      .produced(households[0].agreement.Id, 12, 8000)
      .produced(households[1].agreement.Id, 12, 9500)
      .produced(households[2].agreement.Id, 7, 4000);

    Map<Id, ProductionGuaranteeService.Measurement> measures = ProductionGuaranteeService.measure(
      idsOf(households),
      AS_OF
    );

    ProductionGuaranteeService.Measurement shortOne = measures.get(
      households[0].account.Id
    );
    Assert.areEqual(
      ProductionGuaranteeService.SHORTFALL,
      shortOne.reasonCode,
      'Short'
    );
    Assert.areEqual(1000, shortOne.shortfallKwh.intValue(), 'By 1,000 kWh');
    Assert.areEqual(
      ProductionGuaranteeService.GUARANTEE_MET,
      measures.get(households[1].account.Id).reasonCode,
      'Met'
    );
    ProductionGuaranteeService.Measurement partYear = measures.get(
      households[2].account.Id
    );
    Assert.areEqual(
      ProductionGuaranteeService.NOT_ENOUGH_READINGS,
      partYear.reasonCode,
      'Seven months is not a year'
    );
    Assert.areEqual(7, partYear.monthsOfReadings, 'Says how many');
    Assert.areEqual(
      ProductionGuaranteeService.NOT_ENOUGH_READINGS,
      measures.get(households[3].account.Id).reasonCode,
      'No readings at all'
    );
    Assert.areEqual(
      0,
      [SELECT COUNT() FROM Production_Review__c WITH SYSTEM_MODE],
      'Measuring saves nothing'
    );
  }

  @IsTest
  static void aCreditWorthNothingStillOpensAReviewWithoutOne() {
    List<StewardTestData.Household> households = households();
    households[0].agreement.Monthly_Payment__c = null;
    update households[0].agreement;
    readings().produced(households[0].agreement.Id, 12, 8000);

    ProductionGuaranteeService.review(idsOf(households), AS_OF);

    Production_Review__c review = [
      SELECT Shortfall_kWh__c, Credit_Amount__c, Adjustment__c
      FROM Production_Review__c
      WITH SYSTEM_MODE
    ];
    Assert.areEqual(
      1000,
      review.Shortfall_kWh__c.intValue(),
      'The shortfall is recorded'
    );
    Assert.isTrue(
      review.Credit_Amount__c == 0,
      'With no payment, no rate: ' + review.Credit_Amount__c
    );
    Assert.isNull(
      review.Adjustment__c,
      'So no credit, for a specialist to work out'
    );
  }

  @IsTest
  static void nobodyIsReviewedWhoseHouseholdTheCallerCantSee() {
    List<StewardTestData.Household> households = households();
    readings().produced(households[0].agreement.Id, 12, 8000);
    User outsider = StewardTestData.createUserWithoutAccess();

    Map<Id, ProductionGuaranteeService.Measurement> measures;
    System.runAs(outsider) {
      measures = ProductionGuaranteeService.measure(idsOf(households), AS_OF);
    }

    Assert.isTrue(measures.isEmpty(), 'Nothing to measure: ' + measures);
  }

  @IsTest
  static void noReadingsSourceMeansNoReviews() {
    List<StewardTestData.Household> households = households();

    ProductionGuaranteeService.ReviewRun run = ProductionGuaranteeService.review(
      idsOf(households),
      AS_OF
    );

    Assert.areEqual(
      0,
      run.opened,
      'Until Data 360 is set up, nothing is reviewed'
    );
  }

  @IsTest
  static void twoHundredHouseholdsAreReviewedInOneRun() {
    List<StewardTestData.Household> many = StewardTestData.createHouseholds(
      200,
      StewardTestData.ACCOUNT_CURRENT
    );
    List<ServiceContract> agreements = new List<ServiceContract>();
    KnownReadings known = readings();
    for (StewardTestData.Household household : many) {
      household.agreement.Est_Annual_Production_kWh__c = ESTIMATE;
      agreements.add(household.agreement);
      known.produced(household.agreement.Id, 12, 8000);
    }
    update agreements;

    Test.startTest();
    ProductionGuaranteeService.ReviewRun run = ProductionGuaranteeService.review(
      idsOf(many),
      AS_OF
    );
    Test.stopTest();

    Assert.areEqual(200, run.opened, 'Every one of them');
    Assert.areEqual(
      200,
      [
        SELECT COUNT()
        FROM Adjustment__c
        WHERE Type__c = 'Production Guarantee' AND Amount__c = 144.00
        WITH SYSTEM_MODE
      ],
      'Each with its credit'
    );
  }
}
