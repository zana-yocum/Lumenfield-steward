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

  /** How many times the sessions were looked up. */
  public Integer loads = 0;
  private Map<Id, AgentSession.SessionFacts> facts = new Map<Id, AgentSession.SessionFacts>();

  /**
   * An active web chat.
   * @param n which session, from 1
   * @param authenticatedUserId the customer logged in behind it, or null for an anonymous chat
   * @return this, to add more
   */
  public AgentTestSessions chat(Integer n, Id authenticatedUserId) {
    return add(webChat(n, authenticatedUserId));
  }

  /**
   * A session with any facts. Start from webChat and change what the test is about, such as the
   * status or the channel.
   * @param session the session's facts
   * @return this, to add more
   */
  public AgentTestSessions add(AgentSession.SessionFacts session) {
    facts.put(session.sessionId, session);
    return this;
  }

  /**
   * Makes AgentSession read these sessions for the rest of the test.
   * @return this
   */
  public AgentTestSessions install() {
    AgentSession.source = this;
    return this;
  }

  /**
   * The ID of session n.
   * @param n which session, from 1
   * @return its ID
   */
  public Id id(Integer n) {
    return fakeId(n);
  }

  /**
   * The facts of an active web chat, for a test to change before adding.
   * @param n which session, from 1
   * @param authenticatedUserId the customer logged in behind it, or null
   * @return the facts
   */
  public static AgentSession.SessionFacts webChat(
    Integer n,
    Id authenticatedUserId
  ) {
    AgentSession.SessionFacts session = new AgentSession.SessionFacts();
    session.sessionId = fakeId(n);
    session.status = ACTIVE;
    session.channelType = WEB_CHAT;
    session.authenticatedUserId = authenticatedUserId;
    return session;
  }

  /**
   * A well-formed MessagingSession ID that no record has.
   * @param n which session, from 1
   * @return the ID
   */
  public static Id fakeId(Integer n) {
    return Id.valueOf(
      MessagingSession.SObjectType.getDescribe(SObjectDescribeOptions.DEFERRED)
        .getKeyPrefix() + String.valueOf(n).leftPad(12, '0')
    );
  }

  /**
   * The facts for the sessions the test added.
   * @param sessionIds the sessions asked about
   * @return the ones the test added, keyed by ID
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
