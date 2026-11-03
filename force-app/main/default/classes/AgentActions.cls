/**
 * ST-11, ST-12, GR-01, GR-06, S-07, S-09, NFR-07. What every service-agent action does around its
 * service call, written once: turn the session IDs it was given into households (AgentSession),
 * answer a session with no logged-in customer behind it, record an exception without showing it,
 * and log one record per request (AgentActionLogger). Each action class is then only the call in
 * between and the shape of its answer.
 */
public with sharing class AgentActions {
  /** The reason code on an exception nobody planned for. */
  public static final String UNEXPECTED_ERROR = 'UNEXPECTED_ERROR';

  /** One piece of evidence for a dispute, as the agent passes it on. */
  public class EvidenceLine {
    @AuraEnabled
    public String item;
    /** Required items come first. */
    @AuraEnabled
    public Boolean required;
  }

  /**
   * The household behind each request's session.
   * @param sessionIds the session ID each request gave, in request order; nulls allowed
   * @return identities keyed by session ID exactly as given
   */
  public static Map<String, AgentSession.Identity> identities(
    List<String> sessionIds
  ) {
    return AgentSession.resolve(
      sessionIds == null ? new Set<String>() : new Set<String>(sessionIds)
    );
  }

  /**
   * Answers a request whose session has no verified household: declined, with the reason. Nothing
   * is read for it.
   * @param result the request's result
   * @param identity the session's identity, unverified
   */
  public static void declineUnverified(
    StewardOutcome.Result result,
    AgentSession.Identity identity
  ) {
    result.setOutcome(
      StewardOutcome.DECLINED_POLICY,
      identity?.reasonCode == null
        ? AgentSession.NOT_VERIFIED
        : identity.reasonCode
    );
  }

  /**
   * Evidence items as the agent passes them on, in the catalog's order, required first.
   * @param items DisputeEvidenceCatalog's items; null is treated as none
   * @return one line per item
   */
  public static List<EvidenceLine> evidenceLines(
    List<DisputeEvidenceCatalog.EvidenceItem> items
  ) {
    List<EvidenceLine> lines = new List<EvidenceLine>();
    if (items == null) {
      return lines;
    }
    for (DisputeEvidenceCatalog.EvidenceItem item : items) {
      EvidenceLine line = new EvidenceLine();
      line.item = item.item;
      line.required = item.required;
      lines.add(line);
    }
    return lines;
  }

  /**
   * A record ID the model passed, or null when it isn't a well-formed ID. The services look for an
   * ID only among the household's own records, so a well-formed ID from elsewhere finds nothing
   * too (ST-12).
   * @param value what the model passed
   * @return the ID, or null
   */
  public static Id toId(String value) {
    if (String.isBlank(value)) {
      return null;
    }
    try {
      return Id.valueOf(value.trim());
    } catch (StringException notAnId) {
      return null;
    }
  }

  /**
   * Answers a request that named a record by something that isn't an ID: NOT_FOUND, the same as
   * a record the household doesn't have, so nothing is read and nothing is guessed.
   * @param result the request's result
   */
  public static void declineNotFound(StewardOutcome.Result result) {
    result.setOutcome(StewardOutcome.DECLINED_POLICY, StewardOutcome.NOT_FOUND);
  }

  /**
   * A failure to raise inside an action's service call, for the tests that prove every action's
   * failure path (NFR-07). Always null outside a test.
   */
  @TestVisible
  private static Exception simulatedFailure;

  /** Throws the simulated failure, if a test set one. Does nothing otherwise. */
  public static void failIfSimulated() {
    if (simulatedFailure != null) {
      throw simulatedFailure;
    }
  }

  /**
   * An exception as one line for the log. Never shown to a customer.
   * @param error what was thrown
   * @return its type and message
   */
  public static String describe(Exception error) {
    return error.getTypeName() + ': ' + error.getMessage();
  }

  /**
   * Turns a result into a failure the agent can act on: FAILED, UNEXPECTED_ERROR. The details go
   * only to the log; the customer gets the log's number (log).
   * @param result the request's result
   */
  public static void markFailed(StewardOutcome.Result result) {
    result.setOutcome(StewardOutcome.FAILED, UNEXPECTED_ERROR);
  }

  /**
   * One log entry for a request.
   * @param identity the session's identity; its household and session go on the log
   * @param action the action's class name
   * @param result what the action answered
   * @param details what was asked, in a short line; card numbers are removed when it's saved
   * @return the entry
   */
  public static AgentActionLogger.Entry entry(
    AgentSession.Identity identity,
    String action,
    StewardOutcome.Result result,
    String details
  ) {
    AgentActionLogger.Entry entry = new AgentActionLogger.Entry(
      identity?.accountId,
      action,
      result
    );
    entry.details = details;
    entry.conversationId = identity?.sessionId;
    return entry;
  }

  /**
   * Logs the entries in one save. Each failure gets the log's number as its result's reference,
   * the number a customer can quote (NFR-07).
   * @param entries one per request, in request order
   * @param results the results, in the same order
   */
  public static void log(
    List<AgentActionLogger.Entry> entries,
    List<StewardOutcome.Result> results
  ) {
    List<Database.SaveResult> saved = AgentActionLogger.log(entries);
    Map<Integer, Id> failureLogs = new Map<Integer, Id>();
    for (Integer i = 0; i < saved.size() && i < results.size(); i++) {
      if (results[i].outcome == StewardOutcome.FAILED && saved[i].isSuccess()) {
        failureLogs.put(i, saved[i].getId());
      }
    }
    if (failureLogs.isEmpty()) {
      return;
    }
    Map<Id, String> references = AgentActionLogger.referencesFor(
      new Set<Id>(failureLogs.values())
    );
    for (Integer i : failureLogs.keySet()) {
      results[i].reference = references.get(failureLogs.get(i));
    }
  }
}
