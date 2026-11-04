/**
 * ST-05, S-02. The safety net for online payments: a customer who pays and closes the browser
 * never comes back to the portal to confirm, so this job asks Stripe for every completed checkout
 * session in the last Payment_Reconciliation_Hours and publishes each paid one. The subscriber
 * skips a payment it already recorded, so running the job any number of times records each
 * payment once.
 *
 * Scheduled, it starts one queueable, which can call out. Each queueable reads one page of 100
 * sessions and starts the next until Stripe has no more, up to MAX_PAGES. Every call is on
 * Integration_Log__c, a failed one included.
 */
public with sharing class PaymentReconciliationJob implements Schedulable, Queueable, Database.AllowsCallouts {
  /** 100 sessions a page; a run stops after this many pages and the next run carries on. */
  @TestVisible
  private static final Integer MAX_PAGES = 20;
  /**
   * A test can't start a queueable from a queueable, so in a test each job is kept here instead of
   * being started, and the test runs it.
   */
  @TestVisible
  private static PaymentReconciliationJob nextInTest;

  private final Long createdSince;
  private final String startingAfter;
  private final Integer pageNumber;

  /** The job as scheduled: it works out its window when it runs. */
  public PaymentReconciliationJob() {
    this(null, null, 1);
  }

  private PaymentReconciliationJob(
    Long createdSince,
    String startingAfter,
    Integer pageNumber
  ) {
    this.createdSince = createdSince;
    this.startingAfter = startingAfter;
    this.pageNumber = pageNumber;
  }

  /**
   * Starts a run: the first page, for sessions created in the window.
   * @param context the schedule
   */
  public void execute(SchedulableContext context) {
    Long since =
      Datetime.now()
        .addHours(
          -PolicySettings.getWholeNumber(
            PolicySettings.PAYMENT_RECONCILIATION_HOURS
          )
        )
        .getTime() / 1000;
    start(new PaymentReconciliationJob(since, null, 1));
  }

  /**
   * Where the next page starts, for the tests.
   * @return the session the next page starts after
   */
  @TestVisible
  private String startsAfter() {
    return startingAfter;
  }

  private static void start(PaymentReconciliationJob job) {
    if (Test.isRunningTest()) {
      nextInTest = job;
    } else {
      System.enqueueJob(job);
    }
  }

  /**
   * Reads one page and publishes its paid sessions, then starts the next page if there is one.
   * @param context the queueable
   */
  public void execute(QueueableContext context) {
    if (System.isQueueable()) {
      System.attachFinalizer(new Watch(pageNumber));
    }
    try {
      PaymentCheckoutService.Reconciliation page = PaymentCheckoutService.reconcile(
        createdSince,
        startingAfter
      );
      if (page.hasMore && pageNumber < MAX_PAGES) {
        start(
          new PaymentReconciliationJob(
            createdSince,
            page.lastSessionId,
            pageNumber + 1
          )
        );
      }
    } catch (StripeClient.StripeException stripeError) {
      // Already on Integration_Log__c with Stripe's answer. The next scheduled run tries again.
      IntegrationLogger.Call note = new IntegrationLogger.Call(
        StripeClient.PROVIDER,
        'Reconciliation stopped'
      );
      note.outcome = IntegrationLogger.FAILED;
      note.details = 'Page ' + pageNumber + ': ' + stripeError.getMessage();
      IntegrationLogger.record(note);
    } finally {
      IntegrationLogger.save();
    }
  }

  /**
   * Runs after each page's job, whatever happened. Stripe's own failures are logged by the job; this
   * catches what the job couldn't, such as a limit, so a silent stop still shows on
   * Integration_Log__c.
   */
  public class Watch implements Finalizer {
    private final Integer pageNumber;

    /**
     * A watch on one page's job.
     * @param pageNumber the page
     */
    public Watch(Integer pageNumber) {
      this.pageNumber = pageNumber;
    }

    /**
     * Logs a job that ended with an exception it didn't handle.
     * @param context how the job ended
     */
    public void execute(FinalizerContext context) {
      if (context.getResult() != ParentJobResult.UNHANDLED_EXCEPTION) {
        return;
      }
      Exception error = context.getException();
      IntegrationLogger.Call note = new IntegrationLogger.Call(
        StripeClient.PROVIDER,
        'Reconciliation failed'
      );
      note.outcome = IntegrationLogger.FAILED;
      note.details =
        'Page ' +
        pageNumber +
        ': ' +
        (error == null
          ? 'no exception given'
          : error.getTypeName() + ': ' + error.getMessage());
      IntegrationLogger.record(note);
      IntegrationLogger.save();
    }
  }
}
