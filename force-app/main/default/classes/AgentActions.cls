/**
 * ST-11, ST-12, GR-01, GR-06, S-07, S-09, NFR-07. What every service-agent action does around its
 * service call, written once in Calls: find the household behind each request's session
 * (AgentSession), decline a session with no logged-in customer behind it before anything is read,
 * record an exception without showing it, and log one record per request (AgentActionLogger),
 * giving each failure the log's number to quote. Each action class is then only its service call
 * and the shape of its answer.
 */
public with sharing class AgentActions {
  /** The reason code on an exception nobody planned for. */
  public static final String UNEXPECTED_ERROR = 'UNEXPECTED_ERROR';
  /** The log line for a request the service never answered. */
  @TestVisible
  private static final String NO_ANSWER = 'No answer from the service';

  /** Where a request stands: answered without the service, sent to it, or answered by it. */
  private static final Integer ANSWERED = 0;
  private static final Integer SENT = 1;
  private static final Integer SERVED = 2;

  /**
   * A failure to raise inside an action's service call, for the tests that prove every action's
   * failure path (NFR-07). Always null outside a test.
   */
  @TestVisible
  private static Exception simulatedFailure;

  /** One piece of evidence for a dispute, as the agent passes it on. */
  public class EvidenceLine {
    @AuraEnabled
    public String item;
    /** Required items come first. */
    @AuraEnabled
    public Boolean required;
  }

  /**
   * One call of an action: the requests the agent sent together, in order, each with its
   * session's identity, its answer and its line for the log. The action begins every request,
   * sends the ones still waiting to its service in one call, hands back what the service
   * answered, and finishes, which logs them all.
   */
  public class Calls {
    private final String action;
    private final List<AgentSession.Identity> identities = new List<AgentSession.Identity>();
    /** Each request's empty result, which a decline or a failure fills in. */
    private final List<StewardOutcome.Result> blanks = new List<StewardOutcome.Result>();
    private final List<StewardOutcome.Result> answers = new List<StewardOutcome.Result>();
    private final List<String> details = new List<String>();
    private final List<Integer> states = new List<Integer>();

    /**
     * Finds the household behind each request's session, with two queries however many there
     * are (AgentSession).
     * @param action the action's class name, for the log
     * @param sessionIds each request's session ID, in request order; nulls allowed
     */
    public Calls(String action, List<String> sessionIds) {
      this.action = action;
      Map<String, AgentSession.Identity> resolved = AgentSession.resolve(
        new Set<String>(sessionIds)
      );
      for (String sessionId : sessionIds) {
        identities.add(resolved.get(sessionId));
        blanks.add(null);
        answers.add(null);
        details.add(null);
        states.add(ANSWERED);
      }
    }

    /**
     * How many requests the call has.
     * @return the count
     */
    public Integer count() {
      return states.size();
    }

    /**
     * Request i's household.
     * @param i the request's position
     * @return the verified household, or null
     */
    public Id household(Integer i) {
      return identities[i].accountId;
    }

    /**
     * The households of the requests waiting for the service, for a service that reads by
     * household.
     * @return account IDs
     */
    public Set<Id> households() {
      Set<Id> waiting = new Set<Id>();
      for (Integer i = 0; i < states.size(); i++) {
        if (states[i] == SENT) {
          waiting.add(identities[i].accountId);
        }
      }
      return waiting;
    }

    /**
     * Starts request i. A session with no verified household is declined here, with its reason,
     * and nothing is read for it. Any other request waits for the service.
     * @param i the request's position
     * @param blank an empty result of the action's own kind
     * @param detail what was asked, in a short line for the log; card numbers are removed when
     *               it's saved
     * @return true when the request goes on to the service
     */
    public Boolean begin(
      Integer i,
      StewardOutcome.Result blank,
      String detail
    ) {
      blanks[i] = blank;
      answers[i] = blank;
      details[i] = detail;
      if (identities[i].isVerified()) {
        states[i] = SENT;
        return true;
      }
      blank.setOutcome(
        StewardOutcome.DECLINED_POLICY,
        identities[i].reasonCode
      );
      return false;
    }

    /**
     * Whether a record ID the model passed for request i may be looked up: blank, which the
     * service answers for itself, or a well-formed ID, which the service looks for only among
     * the household's own records (ST-12). Anything else is declined NOT_FOUND, the same as a
     * record the household doesn't have, so nothing is read and nothing is guessed.
     * @param i the request's position
     * @param value what the model passed
     * @return true when the request still goes on to the service
     */
    public Boolean acceptsId(Integer i, String value) {
      if (states[i] != SENT) {
        return false;
      }
      if (String.isBlank(value) || toId(value) != null) {
        return true;
      }
      answers[i]
        .setOutcome(StewardOutcome.DECLINED_POLICY, StewardOutcome.NOT_FOUND);
      states[i] = ANSWERED;
      return false;
    }

    /**
     * The service's answer for request i, if it's waiting for one. A request that was declined
     * keeps its answer.
     * @param i the request's position
     * @param result what the service returned; null leaves the request waiting
     */
    public void serve(Integer i, StewardOutcome.Result result) {
      if (states[i] == SENT && result != null) {
        answers[i] = result;
        states[i] = SERVED;
      }
    }

    /**
     * The service's answers for the requests sent to it.
     * @param sent the requests' positions, in the order their service requests were built
     * @param results the service's results, in the same order
     */
    public void serveAll(
      List<Integer> sent,
      List<StewardOutcome.Result> results
    ) {
      for (Integer q = 0; q < sent.size(); q++) {
        serve(sent[q], results[q]);
      }
    }

    /**
     * Puts the service's own failure message, such as the platform's message when a save fails,
     * in request i's log line in place of what was asked. It goes only to the log.
     * @param i the request's position, answered by the service
     * @param failureDetail the message; null keeps the line from begin
     */
    public void logFailureDetail(Integer i, String failureDetail) {
      if (states[i] == SERVED && failureDetail != null) {
        details[i] = failureDetail;
      }
    }

    /**
     * Records an exception from the service call. Every request that reached the service fails,
     * even one it had already answered, because a write action rolls the whole call back. Each
     * gets its empty result back, marked FAILED with UNEXPECTED_ERROR; the error itself goes only
     * to the log (NFR-07).
     * @param error what was thrown
     */
    public void fail(Exception error) {
      String failure = error.getTypeName() + ': ' + error.getMessage();
      for (Integer i = 0; i < states.size(); i++) {
        if (states[i] != ANSWERED) {
          failed(i, failure);
        }
      }
    }

    /**
     * Logs one record per request in one save and returns the answers. A request the service
     * never answered fails. Each failure gets the log's number as its reference, the number a
     * customer can quote (NFR-07).
     * @return one result per request, in request order: the kind each began with, or the
     *         service's
     */
    public List<StewardOutcome.Result> finish() {
      List<AgentActionLogger.Entry> entries = new List<AgentActionLogger.Entry>();
      for (Integer i = 0; i < states.size(); i++) {
        if (states[i] == SENT) {
          failed(i, NO_ANSWER);
        }
        AgentActionLogger.Entry logged = entry(
          identities[i],
          action,
          answers[i]
        );
        logged.details = details[i];
        entries.add(logged);
      }
      referenceFailures(AgentActionLogger.log(entries));
      return answers;
    }

    private void failed(Integer i, String detail) {
      answers[i] = blanks[i];
      answers[i].setOutcome(StewardOutcome.FAILED, UNEXPECTED_ERROR);
      details[i] = detail;
      states[i] = ANSWERED;
    }

    /**
     * Gives each failure its log record's number, read in one query.
     * @param saved the log's save results, in request order
     */
    private void referenceFailures(List<Database.SaveResult> saved) {
      Map<Integer, Id> failureLogs = new Map<Integer, Id>();
      for (Integer i = 0; i < saved.size(); i++) {
        if (
          answers[i]?.outcome == StewardOutcome.FAILED && saved[i].isSuccess()
        ) {
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
        answers[i].reference = references.get(failureLogs.get(i));
      }
    }
  }

  /**
   * The household behind each session, for an action that answers every request the same way
   * whoever is behind it (RecordHandoffAction).
   * @param sessionIds the session ID each request gave; nulls allowed
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
   * A record ID the model passed, or null when it isn't a well-formed ID.
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

  /** Throws the simulated failure, if a test set one. Does nothing otherwise. */
  public static void failIfSimulated() {
    if (simulatedFailure != null) {
      throw simulatedFailure;
    }
  }

  /**
   * One log entry for a request, naming its household and its conversation. The caller adds the
   * details.
   * @param identity the session's identity
   * @param action the action's class name
   * @param result what the action answered
   * @return the entry
   */
  public static AgentActionLogger.Entry entry(
    AgentSession.Identity identity,
    String action,
    StewardOutcome.Result result
  ) {
    AgentActionLogger.Entry logged = new AgentActionLogger.Entry(
      identity?.accountId,
      action,
      result
    );
    logged.conversationId = identity?.sessionId;
    return logged;
  }
}
