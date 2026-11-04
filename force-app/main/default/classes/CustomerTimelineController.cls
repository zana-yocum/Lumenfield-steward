/**
 * ST-15, ST-12, NFR-06, NFR-07. One household's history on one timeline: statements, payments,
 * promises to pay, billing disputes, credits and commitments, newest first, a page at a time.
 *
 * Every query runs in user mode and names only the fields the person can read (TimelineReader).
 * So a kind of record they can't read isn't offered, and a field they can't read comes back empty.
 * In the console the household is the record page's account, checked with HouseholdScope. On the
 * portal it's always the logged-in customer's own household, whatever the page passes
 * (PortalHousehold), so a customer sees only what their own access allows: nobody else's records,
 * and no credits or commitments, which customers can't read.
 */
public with sharing class CustomerTimelineController {
  public static final String STATEMENT = 'STATEMENT';
  public static final String PAYMENT = 'PAYMENT';
  public static final String PROMISE = 'PROMISE';
  public static final String DISPUTE = 'DISPUTE';
  public static final String CREDIT = 'CREDIT';
  public static final String COMMITMENT = 'COMMITMENT';
  /** How many events a page holds. */
  public static final Integer PAGE_SIZE = 20;
  /** SOQL's largest OFFSET. A kind with more history than this stops paging there. */
  public static final Integer MAX_OFFSET = 2000;
  /** The only cases the timeline shows: billing disputes, never Accord's default reviews. */
  public static final String DISPUTE_RECORD_TYPE = 'Billing_Dispute';
  private static final String ACTION = 'CustomerTimelineController.getTimeline';

  /** A failure to raise, for the test of the failure path (NFR-07). Always null outside a test. */
  @TestVisible
  private static Exception simulatedFailure;

  /** One page of the timeline. */
  public class TimelinePage extends StewardOutcome.Result {
    /** The kinds of record this person can read, in display order. */
    @AuraEnabled
    public List<String> availableKinds = new List<String>();
    /** Newest first. */
    @AuraEnabled
    public List<TimelineEvent> events = new List<TimelineEvent>();
    /** Pass back to get the next page; null when there's nothing more. */
    @AuraEnabled
    public String nextCursor;
  }

  /** One thing that happened on the account. A field the person can't read is null. */
  public class TimelineEvent {
    @AuraEnabled
    public String kind;
    @AuraEnabled
    public Id recordId;
    /** The statement date, payment date, promised date, opened date, posted date or signing date. */
    @AuraEnabled
    public Date eventDate;
    /** The record's number, such as STMT-00123 or a case number. */
    @AuraEnabled
    public String name;
    /** Amount due, amount paid, amount promised, credit amount or commitment value. */
    @AuraEnabled
    public Decimal amount;
    /** Statements only. */
    @AuraEnabled
    public Decimal balance;
    /** Statements only. */
    @AuraEnabled
    public Date dueDate;
    @AuraEnabled
    public String status;
    /** A dispute's reason, a credit's type or a commitment's type. */
    @AuraEnabled
    public String detail;
  }

  /**
   * A page of one household's history.
   * @param recordId the record page's account; ignored on the portal
   * @param kinds the kinds to show; empty or null shows every kind the person can read
   * @param cursor the previous page's nextCursor, or null for the first page
   * @return the page; NOT_FOUND for an account out of reach, INVALID_REQUEST for a bad cursor
   */
  @AuraEnabled
  public static TimelinePage getTimeline(
    Id recordId,
    List<String> kinds,
    String cursor
  ) {
    TimelinePage page = new TimelinePage();
    Id household;
    try {
      if (simulatedFailure != null) {
        throw simulatedFailure;
      }
      household = householdFor(recordId);
      Map<String, Integer> offsets = TimelineCursor.parse(cursor);
      if (household == null) {
        page.setOutcome(
          StewardOutcome.DECLINED_POLICY,
          StewardOutcome.NOT_FOUND
        );
      } else if (offsets == null) {
        page.setOutcome(
          StewardOutcome.DECLINED_POLICY,
          StewardOutcome.INVALID_REQUEST
        );
      } else {
        new TimelineReader(household, PAGE_SIZE).fill(page, kinds, offsets);
        page.setOutcome(StewardOutcome.COMPLETED, null);
      }
    } catch (Exception error) {
      page = new TimelinePage();
      new PortalFailure(household, ACTION).recordException(page, error);
    }
    return page;
  }

  /**
   * The household this person may see the history of. A customer always gets their own; anyone
   * else gets the record page's account, if it's a household they can see.
   * @param recordId the record page's account
   * @return the household, or null
   */
  private static Id householdFor(Id recordId) {
    Id own = PortalHousehold.current();
    if (own != null) {
      return own;
    }
    return recordId != null && HouseholdScope.isVisible(recordId)
      ? recordId
      : null;
  }
}
