/**
 * ST-14, S-29. Runs the production guarantee review once a month, for every household whose
 * agreement records its estimated production. Scheduled by an admin, it runs as them, so the
 * reviews and Draft credits it opens are created with their access.
 */
public with sharing class ProductionReviewJob implements Schedulable {
  /**
   * Reviews last month's 12-month window.
   * @param context the schedule
   */
  public void execute(SchedulableContext context) {
    run(Date.today());
  }

  /**
   * Reviews every household with an estimate, as of a day.
   * @param asOf the day the review runs; the window ends with the month before
   * @return what was measured, opened and found already reviewed
   */
  @TestVisible
  private static ProductionGuaranteeService.ReviewRun run(Date asOf) {
    Set<Id> households = new Set<Id>();
    for (ServiceContract agreement : [
      SELECT AccountId
      FROM ServiceContract
      WHERE Est_Annual_Production_kWh__c != NULL AND AccountId != NULL
      WITH USER_MODE
    ]) {
      households.add(agreement.AccountId);
    }
    return ProductionGuaranteeService.review(households, asOf);
  }
}
