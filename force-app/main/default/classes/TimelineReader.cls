/**
 * ST-15, ST-12, NFR-01. Reads one household's timeline for CustomerTimelineController, in user
 * mode.
 *
 * Each kind of event (TimelineKind) is one query. A kind is offered only when the person can read
 * its object, its date and the field that ties it to the household. Any other field is selected
 * only when they can read it, so a field they can't read comes back empty instead of failing the
 * page. Each kind is read newest first, one page plus one record at a time, from where the last
 * page stopped (TimelineCursor). The kinds are merged by date, and the extra record says whether a
 * kind has more.
 */
public with sharing class TimelineReader {
  private static final List<String> OBJECTS = new List<String>{
    'Billing_Statement__c',
    'Payment__c',
    'Promise_to_Pay__c',
    'Case',
    'Adjustment__c',
    'Commitment__c',
    'Opportunity'
  };
  /** The object each relationship in a path reaches. */
  private static final Map<String, String> TARGETS = new Map<String, String>{
    'Billing_Statement__r' => 'Billing_Statement__c',
    'Opportunity__r' => 'Opportunity'
  };
  /** Sorts before every real date, for a record with none. */
  private static final Date UNDATED = Date.newInstance(1900, 1, 1);

  private final Id household;
  private final Integer pageSize;
  private final Map<String, Boolean> readableObjects = new Map<String, Boolean>();
  private final Map<String, Map<String, Schema.SObjectField>> fieldsByObject = new Map<String, Map<String, Schema.SObjectField>>();
  private final List<TimelineKind> queried = new List<TimelineKind>();
  private final List<List<CustomerTimelineController.TimelineEvent>> lists = new List<List<CustomerTimelineController.TimelineEvent>>();

  /**
   * A reader for one household.
   * @param household the household, already in reach of the person
   * @param pageSize how many events a page holds
   */
  public TimelineReader(Id household, Integer pageSize) {
    this.household = household;
    this.pageSize = pageSize;
    for (
      Schema.DescribeSObjectResult described : Schema.describeSObjects(
        OBJECTS,
        SObjectDescribeOptions.DEFERRED
      )
    ) {
      readableObjects.put(described.getName(), described.isAccessible());
      fieldsByObject.put(described.getName(), described.fields.getMap());
    }
  }

  /**
   * Fills a page: the kinds the person can read, and the next events of the kinds asked for.
   * @param page the page to fill
   * @param wanted the kinds asked for; empty or null for every readable kind
   * @param offsets how many of each kind earlier pages showed
   */
  public void fill(
    CustomerTimelineController.TimelinePage page,
    List<String> wanted,
    Map<String, Integer> offsets
  ) {
    Set<String> asked = wanted == null
      ? new Set<String>()
      : new Set<String>(wanted);
    for (TimelineKind kind : TimelineKind.all()) {
      if (isReadable(kind)) {
        page.availableKinds.add(kind.code);
        Integer offset = offsetOf(offsets, kind.code);
        if (
          (asked.isEmpty() || asked.contains(kind.code)) &&
          offset <= CustomerTimelineController.MAX_OFFSET
        ) {
          queried.add(kind);
          lists.add(read(kind, offset));
        }
      }
    }
    takePage(page, offsets);
  }

  /**
   * Whether the person can read a kind: its object, the field that ties it to the household, its
   * date, and any field its query filters on. User mode refuses a query that names a field the
   * person can't read, so a kind they can't fully read isn't offered at all.
   * @param kind the kind
   * @return true when all of those are readable
   */
  private Boolean isReadable(TimelineKind kind) {
    return readableObjects.get(kind.objectName) == true &&
      canRead(kind.objectName, kind.householdPath) &&
      canRead(kind.objectName, kind.datePath) &&
      (kind.conditionField == null ||
      canRead(kind.objectName, kind.conditionField));
  }

  /**
   * Whether the person can read a field, or every step of a path such as Opportunity__r.CloseDate.
   * @param objectName the object the path starts from
   * @param path a field or a one-step relationship path
   * @return true when every field and object on the way is readable
   */
  private Boolean canRead(String objectName, String path) {
    if (!path.contains('.')) {
      return isReadableField(objectName, path);
    }
    String relationship = path.substringBefore('.');
    String target = TARGETS.get(relationship);
    return isReadableField(objectName, relationship.removeEnd('__r') + '__c') &&
      readableObjects.get(target) == true &&
      isReadableField(target, path.substringAfter('.'));
  }

  private Boolean isReadableField(String objectName, String fieldName) {
    Schema.SObjectField field = fieldsByObject.get(objectName)?.get(fieldName);
    return field != null && field.getDescribe().isAccessible();
  }

  /**
   * The next events of one kind, newest first: a page plus one, to tell whether there are more.
   * @param kind the kind
   * @param offset how many of it earlier pages showed
   * @return the events
   */
  private List<CustomerTimelineController.TimelineEvent> read(
    TimelineKind kind,
    Integer offset
  ) {
    List<String> fields = new List<String>{
      'Id',
      kind.nameField,
      kind.datePath
    };
    Map<String, String> readable = new Map<String, String>();
    for (String property : kind.shown.keySet()) {
      String path = kind.shown.get(property);
      if (canRead(kind.objectName, path)) {
        readable.put(property, path);
        fields.add(path);
      }
    }
    Map<String, Object> binds = new Map<String, Object>{
      'household' => household,
      'rowLimit' => pageSize + 1,
      'rowOffset' => offset
    };
    if (kind.conditionField != null) {
      binds.put('conditionValue', kind.conditionValue);
    }
    List<CustomerTimelineController.TimelineEvent> events = new List<CustomerTimelineController.TimelineEvent>();
    for (
      SObject row : Database.queryWithBinds(
        kind.query(fields),
        binds,
        AccessLevel.USER_MODE
      )
    ) {
      events.add(kind.toEvent(row, readable));
    }
    return events;
  }

  /**
   * Takes the page's events from the kinds' lists, latest date first, and works out the cursor.
   * The lists are in display order, so on the same date the earlier kind comes first. A kind that
   * wasn't read this time, because it reached MAX_OFFSET, keeps its count in the cursor, so a
   * later page never starts it again from the top.
   * @param page the page to fill
   * @param offsets how many of each kind earlier pages showed
   */
  private void takePage(
    CustomerTimelineController.TimelinePage page,
    Map<String, Integer> offsets
  ) {
    List<Integer> taken = new List<Integer>();
    for (Integer i = 0; i < lists.size(); i++) {
      taken.add(0);
    }
    Integer next = latest(taken);
    while (next != null && page.events.size() < pageSize) {
      page.events.add(lists[next][taken[next]]);
      taken[next] = taken[next] + 1;
      next = latest(taken);
    }
    Map<String, Integer> nextOffsets = new Map<String, Integer>(offsets);
    Boolean more = false;
    for (Integer i = 0; i < lists.size(); i++) {
      String code = queried[i].code;
      nextOffsets.put(code, offsetOf(offsets, code) + taken[i]);
      more = more || lists[i].size() > taken[i];
    }
    page.nextCursor = more ? TimelineCursor.format(nextOffsets) : null;
  }

  /**
   * The list whose next event is latest.
   * @param taken how many of each list the page has taken
   * @return its position, or null when every list is used up
   */
  private Integer latest(List<Integer> taken) {
    Integer best;
    Date bestDate;
    for (Integer i = 0; i < lists.size(); i++) {
      if (taken[i] < lists[i].size()) {
        Date candidate = lists[i][taken[i]].eventDate;
        candidate = candidate == null ? UNDATED : candidate;
        if (best == null || candidate > bestDate) {
          best = i;
          bestDate = candidate;
        }
      }
    }
    return best;
  }

  private static Integer offsetOf(Map<String, Integer> offsets, String code) {
    return offsets.containsKey(code) ? offsets.get(code) : 0;
  }
}
