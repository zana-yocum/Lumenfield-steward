/**
 * Phase 6, S-07, S-23. Messaging sessions for tests. A test can't open a real chat, so this stands
 * in for the org's messaging records: each session is a well-formed MessagingSession ID that no
 * record has, with the facts the test gives it. The customer users and households behind them are
 * real, from StewardTestData and PortalTestData.
 */
@IsTest
public class AgentTestSessions implements AgentSession.SessionSource {
  /** Enhanced Chat's channel type, the portal's web chat. */
  public static final String WEB_CHAT = 'EmbeddedMessaging';
  public static final String ACTIVE = 'Active';

  private Map<Id, AgentSession.SessionFacts> facts = new Map<Id, AgentSession.SessionFacts>();
  /** How many times the sessions were looked up. */
  public Integer loads = 0;

  /**
   * An active web chat.
   * @param n which session, 1 and up
   * @param authenticatedUserId the portal user logged in behind it, or null for an anonymous chat
   * @return these sessions, to chain calls
   */
  public AgentTestSessions chat(Integer n, Id authenticatedUserId) {
    return add(id(n), ACTIVE, WEB_CHAT, authenticatedUserId);
  }

  /**
   * A session with any facts.
   * @param sessionId its ID
   * @param status MessagingSession.Status
   * @param channelType MessagingSession.ChannelType
   * @param authenticatedUserId MessagingEndUser.AuthenticatedEndUserId
   * @return these sessions, to chain calls
   */
  public AgentTestSessions add(
    Id sessionId,
    String status,
    String channelType,
    Id authenticatedUserId
  ) {
    AgentSession.SessionFacts session = new AgentSession.SessionFacts();
    session.sessionId = sessionId;
    session.status = status;
    session.channelType = channelType;
    session.authenticatedUserId = authenticatedUserId;
    facts.put(sessionId, session);
    return this;
  }

  /**
   * Makes AgentSession read these sessions for the rest of the test.
   * @return these sessions, to chain calls
   */
  public AgentTestSessions install() {
    AgentSession.source = this;
    return this;
  }

  /**
   * The ID of session n.
   * @param n which session, 1 and up
   * @return a well-formed MessagingSession ID that no record has
   */
  public Id id(Integer n) {
    return fakeId(n);
  }

  /**
   * A well-formed MessagingSession ID that no record has.
   * @param n which one, 1 and up
   * @return the ID
   */
  public static Id fakeId(Integer n) {
    return Id.valueOf(
      MessagingSession.SObjectType.getDescribe().getKeyPrefix() +
      String.valueOf(n).leftPad(12, '0')
    );
  }

  /**
   * The facts for the sessions the test added.
   * @param sessionIds the sessions asked for
   * @return facts for those that were added
   */
  public Map<Id, AgentSession.SessionFacts> load(Set<Id> sessionIds) {
    loads++;
    Map<Id, AgentSession.SessionFacts> found = new Map<Id, AgentSession.SessionFacts>();
    for (Id sessionId : sessionIds) {
      if (facts.containsKey(sessionId)) {
        found.put(sessionId, facts.get(sessionId));
      }
    }
    return found;
  }
}
