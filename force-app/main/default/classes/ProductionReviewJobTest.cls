/**
 * ST-14, S-29. Proves the monthly job reviews every household whose agreement records an
 * estimate, and only those, when the schedule fires.
 */
@IsTest
private class ProductionReviewJobTest {
  /** Every agreement produced 8,000 kWh over the 12 months, short of a 9,000 kWh guarantee. */
  private class ShortEverywhere implements ProductionGuaranteeService.Readings {
    /**
     * 12 months and 8,000 kWh for every agreement asked about.
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
      Map<Id, ProductionGuaranteeService.Production> found = new Map<Id, ProductionGuaranteeService.Production>();
      for (Id agreementId : agreementIds) {
        ProductionGuaranteeService.Production production = new ProductionGuaranteeService.Production();
        production.months = 12;
        production.kWh = 8000;
        found.put(agreementId, production);
      }
      return found;
    }
  }

  @TestSetup
  static void createData() {
    List<StewardTestData.Household> households = StewardTestData.createHouseholds(
      3,
      StewardTestData.ACCOUNT_CURRENT
    );
    households[0].agreement.Est_Annual_Production_kWh__c = 10000;
    households[1].agreement.Est_Annual_Production_kWh__c = 10000;
    update new List<ServiceContract>{
      households[0].agreement,
      households[1].agreement
    };
  }

  @IsTest
  static void theScheduleReviewsEveryHouseholdWithAnEstimate() {
    ProductionGuaranteeService.source = new ShortEverywhere();

    Test.startTest();
    System.schedule(
      'Steward Production Review test',
      '0 0 6 2 * ?',
      new ProductionReviewJob()
    );
    Test.stopTest();

    Assert.areEqual(
      2,
      [SELECT COUNT() FROM Production_Review__c WITH SYSTEM_MODE],
      'The two with an estimate, not the third'
    );
  }

  @IsTest
  static void aRunSaysWhatItDid() {
    ProductionGuaranteeService.source = new ShortEverywhere();

    ProductionGuaranteeService.ReviewRun run = ProductionReviewJob.run(
      Date.newInstance(2026, 11, 2)
    );

    Assert.areEqual(2, run.measured, 'Two measured');
    Assert.areEqual(2, run.opened, 'Two opened');
  }
}
