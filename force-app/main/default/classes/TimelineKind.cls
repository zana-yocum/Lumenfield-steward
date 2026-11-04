/**
 * ST-15. One kind of event on the customer timeline: the object it lives in, how it's tied to the
 * household, which date places it on the timeline, and the fields it shows when the person can
 * read them. all() lists the six kinds in the order the timeline shows them on the same date.
 *
 * Each kind's query is ordered by the same date that places its events on the timeline, so every
 * kind's events come back newest first and TimelineReader can merge them. That's why credits
 * appear once they're posted, on their posted date: drafts and credits waiting for approval are
 * work in progress, and stay in the account's Adjustments list.
 */
public with sharing class TimelineKind {
  /** The only credits the timeline shows. */
  @TestVisible
  private static final String POSTED = 'Posted';

  public final String code;
  public final String objectName;
  /** The field that ties a record to the household, such as Account__c. */
  public String householdPath { get; private set; }
  /** The date that places a record on the timeline, and orders the kind's query. */
  public String datePath { get; private set; }
  /** True when datePath is a date and time, such as CreatedDate, shown as the person's own date. */
  public Boolean datedByTimestamp { get; private set; }
  /** The record's number: Name, or CaseNumber for a case. */
  public String nameField { get; private set; }
  /** A field the kind's records must match, such as a case's record type. Null for most kinds. */
  public String conditionField { get; private set; }
  /** The value conditionField must have. */
  public Object conditionValue { get; private set; }
  /** Event property → field path, for the fields shown when readable. */
  public final Map<String, String> shown = new Map<String, String>();

  /**
   * A kind of event.
   * @param code its code, such as STATEMENT
   * @param objectName the object its records live in
   */
  public TimelineKind(String code, String objectName) {
    this.code = code;
    this.objectName = objectName;
    this.nameField = 'Name';
    this.datedByTimestamp = false;
  }

  /**
   * The six kinds, in the order the timeline shows them on the same date.
   * @return the kinds
   */
  public static List<TimelineKind> all() {
    return new List<TimelineKind>{
      new TimelineKind(
          CustomerTimelineController.STATEMENT,
          'Billing_Statement__c'
        )
        .tiedBy('Account__c')
        .datedBy('Statement_Date__c')
        .showing('amount', 'Amount_Due__c')
        .showing('balance', 'Balance__c')
        .showing('dueDate', 'Due_Date__c')
        .showing('status', 'Status__c'),
      new TimelineKind(CustomerTimelineController.PAYMENT, 'Payment__c')
        .tiedBy('Billing_Statement__r.Account__c')
        .datedBy('Payment_Date__c')
        .showing('amount', 'Amount__c'),
      new TimelineKind(CustomerTimelineController.PROMISE, 'Promise_to_Pay__c')
        .tiedBy('Account__c')
        .datedBy('Promise_Date__c')
        .showing('amount', 'Promise_Amount__c')
        .showing('status', 'Status__c'),
      new TimelineKind(CustomerTimelineController.DISPUTE, 'Case')
        .tiedBy('AccountId')
        .datedByTimestamp('CreatedDate')
        .namedBy('CaseNumber')
        .onlyWhen('RecordTypeId', disputeRecordTypeId())
        .showing('status', 'Status')
        .showing('detail', 'Dispute_Reason__c'),
      new TimelineKind(CustomerTimelineController.CREDIT, 'Adjustment__c')
        .tiedBy('Account__c')
        .datedBy('Posted_Date__c')
        .onlyWhen('Status__c', POSTED)
        .showing('amount', 'Amount__c')
        .showing('status', 'Status__c')
        .showing('detail', 'Type__c'),
      new TimelineKind(CustomerTimelineController.COMMITMENT, 'Commitment__c')
        .tiedBy('Account__c')
        .datedBy('Opportunity__r.CloseDate')
        .showing('amount', 'Value__c')
        .showing('status', 'Status__c')
        .showing('detail', 'Type__c')
    };
  }

  /**
   * The query for this kind's next records, newest first. It names only constant field paths from
   * all(), already filtered to what the person can read, and binds every value: :household,
   * :conditionValue, :rowLimit and :rowOffset.
   * @param fields the fields to select
   * @return the query
   */
  public String query(List<String> fields) {
    return 'SELECT ' +
      String.join(fields, ', ') +
      ' FROM ' +
      objectName +
      ' WHERE ' +
      householdPath +
      ' = :household' +
      (conditionField == null
        ? ''
        : ' AND ' + conditionField + ' = :conditionValue') +
      ' ORDER BY ' +
      datePath +
      ' DESC NULLS LAST, Id DESC LIMIT :rowLimit OFFSET :rowOffset';
  }

  /**
   * One record as a timeline event.
   * @param row the record
   * @param readable property → field path, for the shown fields the person can read
   * @return the event; a field the person can't read stays null
   */
  public CustomerTimelineController.TimelineEvent toEvent(
    SObject row,
    Map<String, String> readable
  ) {
    CustomerTimelineController.TimelineEvent event = new CustomerTimelineController.TimelineEvent();
    event.kind = code;
    event.recordId = row.Id;
    event.name = (String) row.get(nameField);
    event.eventDate = datedByTimestamp
      ? ((Datetime) valueAt(row, datePath))?.date()
      : (Date) valueAt(row, datePath);
    event.amount = (Decimal) valueAt(row, readable.get('amount'));
    event.balance = (Decimal) valueAt(row, readable.get('balance'));
    event.dueDate = (Date) valueAt(row, readable.get('dueDate'));
    event.status = (String) valueAt(row, readable.get('status'));
    event.detail = (String) valueAt(row, readable.get('detail'));
    return event;
  }

  private TimelineKind tiedBy(String path) {
    householdPath = path;
    return this;
  }

  private TimelineKind datedBy(String path) {
    datePath = path;
    return this;
  }

  // Apex can't tell a date from a date and time with instanceof: a Date passes instanceof Datetime,
  // and converting it would move it a day for anyone west of Greenwich. So each kind says which it is.
  private TimelineKind datedByTimestamp(String path) {
    datePath = path;
    datedByTimestamp = true;
    return this;
  }

  private TimelineKind namedBy(String field) {
    nameField = field;
    return this;
  }

  private TimelineKind onlyWhen(String field, Object value) {
    conditionField = field;
    conditionValue = value;
    return this;
  }

  private TimelineKind showing(String property, String path) {
    shown.put(property, path);
    return this;
  }

  /**
   * The Billing Dispute record type, so the timeline never shows Accord's default reviews.
   * @return its ID, or null if the org has no such record type, which matches no case
   */
  private static Id disputeRecordTypeId() {
    return Schema.SObjectType.Case.getRecordTypeInfosByDeveloperName()
      .get(CustomerTimelineController.DISPUTE_RECORD_TYPE)
      ?.getRecordTypeId();
  }

  private static Object valueAt(SObject row, String path) {
    if (path == null) {
      return null;
    }
    if (!path.contains('.')) {
      return row.get(path);
    }
    SObject parent = row.getSObject(path.substringBefore('.'));
    return parent?.get(path.substringAfter('.'));
  }
}
