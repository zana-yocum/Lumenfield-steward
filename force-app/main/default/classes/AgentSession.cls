/**
 * ST-12, GR-01, S-07, S-23. The household a service-agent conversation acts for. It comes from the
 * conversation's own records, never from what the customer types: the agent passes the messaging
 * session's ID, bound in the agent to $Context.RoutableId so the model can't fill it, and this
 * class follows the platform's links from there. The session's messaging user, the portal user
 * the platform authenticated for them (MessagingEndUser.AuthenticatedEndUserId, which no API call,
 * rep or model can set), and that user's account. A session that isn't the portal's web chat, has
 * ended, or has no logged-in customer behind it resolves to no household.
 */
public with sharing class AgentSession {
  /** No logged-in customer behind the session: anonymous, an employee, or an inactive user. */
  public static final String NOT_VERIFIED = 'NOT_VERIFIED';
  /** The conversation has ended, so nothing more is done in it. */
  public static final String SESSION_ENDED = 'SESSION_ENDED';
  /** Not the portal's web chat, the only channel the agent serves (S-11). */
  public static final String WRONG_CHANNEL = 'WRONG_CHANNEL';

  /** Enhanced Chat, the web chat on the portal. */
  @TestVisible
  private static final String WEB_CHAT = 'EmbeddedMessaging';
  @TestVisible
  private static final Set<String> ENDED_STATUSES = new Set<String>{
    'Ended',
    'Inactive',
    'Error'
  };
  /** Customer Community and Customer Community Plus users. Partners and employees aren't customers. */
  @TestVisible
  private static final Set<String> CUSTOMER_USER_TYPES = new Set<String>{
    'CspLitePortal',
    'PowerCustomerSuccess',
    'CustomerSuccess'
  };

  /** Who a session is for. */
  public class Identity {
    /** The session ID as the agent passed it, which is also the conversation the log names. */
    public String sessionId;
    /** The verified household, or null. */
    public Id accountId;
    /** Why there's no household: NOT_VERIFIED, SESSION_ENDED or WRONG_CHANNEL. Null when verified. */
    public String reasonCode;

    /**
     * Whether the session has a logged-in customer's household behind it.
     * @return true when accountId is set
     */
    public Boolean isVerified() {
      return accountId != null;
    }
  }

  /** What the platform records about one session. */
  public class SessionFacts {
    public Id sessionId;
    public String status;
    public String channelType;
    /** The portal user the platform authenticated, or null for an anonymous chat. */
    public Id authenticatedUserId;
  }

  /** Where session facts come from. Tests replace it, because a test can't open a real chat. */
  public interface SessionSource {
    /**
     * The facts for the sessions that exist.
     * @param sessionIds the sessions to look up
     * @return facts keyed by session ID; a missing key means no such session
     */
    Map<Id, SessionFacts> load(Set<Id> sessionIds);
  }

  @TestVisible
  private static SessionSource source = new Elevated();

  /**
   * The household for one session.
   * @param sessionId the messaging session's ID, from $Context.RoutableId
   * @return the identity; never null
   */
  public static Identity resolve(String sessionId) {
    return resolve(new Set<String>{ sessionId }).get(sessionId);
  }

  /**
   * The household for each session, with two queries however many there are.
   * @param sessionIds messaging session IDs, from $Context.RoutableId
   * @return one identity per given ID, keyed by that ID exactly as given
   */
  public static Map<String, Identity> resolve(Set<String> sessionIds) {
    Map<String, Identity> identities = new Map<String, Identity>();
    if (sessionIds == null) {
      return identities;
    }
    Map<String, Id> parsed = new Map<String, Id>();
    for (String given : sessionIds) {
      Identity identity = new Identity();
      identity.sessionId = given;
      identity.reasonCode = NOT_VERIFIED;
      identities.put(given, identity);
      Id sessionId = toSessionId(given);
      if (sessionId != null) {
        parsed.put(given, sessionId);
      }
    }
    if (parsed.isEmpty()) {
      return identities;
    }
    Map<Id, SessionFacts> facts = source.load(new Set<Id>(parsed.values()));
    Map<Id, Id> householdByUser = householdsOfCustomers(facts.values());
    for (String given : parsed.keySet()) {
      decide(
        identities.get(given),
        facts.get(parsed.get(given)),
        householdByUser
      );
    }
    return identities;
  }

  private static void decide(
    Identity identity,
    SessionFacts facts,
    Map<Id, Id> householdByUser
  ) {
    if (facts == null) {
      return;
    }
    if (facts.channelType != WEB_CHAT) {
      identity.reasonCode = WRONG_CHANNEL;
      return;
    }
    if (ENDED_STATUSES.contains(facts.status)) {
      identity.reasonCode = SESSION_ENDED;
      return;
    }
    Id household = householdByUser.get(facts.authenticatedUserId);
    if (household != null) {
      identity.accountId = household;
      identity.reasonCode = null;
    }
  }

  /**
   * A messaging session ID, or null for anything else: blank, malformed, or another object's ID.
   * @param given the value the agent passed
   * @return the ID, or null
   */
  @TestVisible
  private static Id toSessionId(String given) {
    if (String.isBlank(given)) {
      return null;
    }
    try {
      Id candidate = Id.valueOf(given.trim());
      return candidate.getSobjectType() == MessagingSession.SObjectType
        ? candidate
        : null;
    } catch (StringException notAnId) {
      return null;
    }
  }

  /**
   * The household of each authenticated user who is an active customer.
   * @param facts the sessions found
   * @return account IDs keyed by user ID
   */
  private static Map<Id, Id> householdsOfCustomers(List<SessionFacts> facts) {
    Set<Id> userIds = new Set<Id>();
    for (SessionFacts session : facts) {
      if (session.authenticatedUserId != null) {
        userIds.add(session.authenticatedUserId);
      }
    }
    return userIds.isEmpty()
      ? new Map<Id, Id>()
      : new Elevated().customerHouseholds(userIds);
  }

  /**
   * The facts for one session record. Separate from the query so a test can check the mapping on a
   * record built in memory.
   * @param session a MessagingSession with Status, ChannelType and the messaging user's
   *                AuthenticatedEndUserId
   * @return its facts
   */
  @TestVisible
  private static SessionFacts factsFrom(MessagingSession session) {
    SessionFacts facts = new SessionFacts();
    facts.sessionId = session.Id;
    facts.status = session.Status;
    facts.channelType = session.ChannelType;
    facts.authenticatedUserId = session.MessagingEndUser
      ?.AuthenticatedEndUserId;
    return facts;
  }

  // S-23: the session, its messaging user and the customer's user record are read in system mode.
  // The agent user has no access to messaging records or to customers' user records, and shouldn't
  // need any: these reads follow links only the platform sets, from an ID the model never chooses,
  // and return nothing but an account ID. Every read of the household's own records afterwards is
  // in user mode, as the agent user (S-01), through the services.
  private without sharing class Elevated implements SessionSource {
    /**
     * The facts for the sessions that exist.
     * @param sessionIds the sessions to look up
     * @return facts keyed by session ID
     */
    public Map<Id, SessionFacts> load(Set<Id> sessionIds) {
      Map<Id, SessionFacts> facts = new Map<Id, SessionFacts>();
      for (MessagingSession session : [
        SELECT Id, Status, ChannelType, MessagingEndUser.AuthenticatedEndUserId
        FROM MessagingSession
        WHERE Id IN :sessionIds
        WITH SYSTEM_MODE
      ]) {
        facts.put(session.Id, factsFrom(session));
      }
      return facts;
    }

    /**
     * The household of each user who is an active customer.
     * @param userIds the authenticated users
     * @return account IDs keyed by user ID
     */
    public Map<Id, Id> customerHouseholds(Set<Id> userIds) {
      Map<Id, Id> households = new Map<Id, Id>();
      for (User customer : [
        SELECT Id, AccountId
        FROM User
        WHERE
          Id IN :userIds
          AND IsActive = TRUE
          AND UserType IN :CUSTOMER_USER_TYPES
          AND ContactId != NULL
          AND AccountId != NULL
        WITH SYSTEM_MODE
      ]) {
        households.put(customer.Id, customer.AccountId);
      }
      return households;
    }
  }
}
