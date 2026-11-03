/**
 * ST-12, GR-01, S-07, S-23. Proves a conversation's household comes from the platform's record of
 * who is logged in, and from nothing else. A test can't open a real chat, so the session's facts
 * come from a stand-in; the customer users and households are real.
 */
@IsTest
private class AgentSessionTest {
  private static final String WEB_CHAT = 'EmbeddedMessaging';
  private static final String ACTIVE = 'Active';

  @TestSetup
  static void createData() {
    PortalTestData.giveRunningUserARole();
    StewardTestData.createHouseholds(2, StewardTestData.ACCOUNT_DELINQUENT);
  }

  @IsTest
  static void aLoggedInCustomersChatActsForTheirOwnHousehold() {
    List<StewardTestData.Household> households = StewardTestData.existingHouseholds();
    List<User> customers = PortalTestData.createCustomers(households);
    Id first = fakeSessionId(1);
    Id second = fakeSessionId(2);
    Sessions sessions = new Sessions()
      .add(first, ACTIVE, WEB_CHAT, customers[0].Id)
      .add(second, ACTIVE, WEB_CHAT, customers[1].Id);
    AgentSession.source = sessions;

    Test.startTest();
    Map<String, AgentSession.Identity> identities = AgentSession.resolve(
      new Set<String>{ String.valueOf(first), String.valueOf(second) }
    );
    Test.stopTest();

    AgentSession.Identity firstIdentity = identities.get(String.valueOf(first));
    AgentSession.Identity secondIdentity = identities.get(
      String.valueOf(second)
    );
    Assert.areEqual(
      households[0].account.Id,
      firstIdentity.accountId,
      'The first chat acts for the first customer\'s household: ' +
      firstIdentity.reasonCode
    );
    Assert.areEqual(
      households[1].account.Id,
      secondIdentity.accountId,
      'The second chat acts for the second customer\'s household, not the first'
    );
    Assert.isTrue(firstIdentity.isVerified(), 'A verified identity says so');
    Assert.isNull(firstIdentity.reasonCode, 'No reason code when verified');
    Assert.areEqual(1, sessions.loads, 'Both sessions are looked up together');
  }

  @IsTest
  static void anAnonymousChatHasNoHousehold() {
    Id session = fakeSessionId(1);
    AgentSession.source = new Sessions().add(session, ACTIVE, WEB_CHAT, null);

    AgentSession.Identity identity = AgentSession.resolve(session);

    Assert.isNull(identity.accountId, 'Nobody is logged in behind the chat');
    Assert.isFalse(identity.isVerified(), 'Not verified');
    Assert.areEqual(AgentSession.NOT_VERIFIED, identity.reasonCode, 'Reason');
  }

  @IsTest
  static void anEmployeeLoggedInIsNotACustomer() {
    Id session = fakeSessionId(1);
    AgentSession.source = new Sessions()
      .add(session, ACTIVE, WEB_CHAT, UserInfo.getUserId());

    AgentSession.Identity identity = AgentSession.resolve(session);

    Assert.isNull(
      identity.accountId,
      'An internal user has no household, even logged in to the site'
    );
    Assert.areEqual(AgentSession.NOT_VERIFIED, identity.reasonCode, 'Reason');
  }

  @IsTest
  static void aDeactivatedCustomerIsNotVerified() {
    List<StewardTestData.Household> households = StewardTestData.existingHouseholds();
    User customer = PortalTestData.createCustomers(households)[0];
    System.runAs(new User(Id = UserInfo.getUserId())) {
      update new User(Id = customer.Id, IsActive = false);
    }
    Id session = fakeSessionId(1);
    AgentSession.source = new Sessions()
      .add(session, ACTIVE, WEB_CHAT, customer.Id);

    AgentSession.Identity identity = AgentSession.resolve(session);

    Assert.isNull(
      identity.accountId,
      'A customer whose login was turned off has no household'
    );
    Assert.areEqual(AgentSession.NOT_VERIFIED, identity.reasonCode, 'Reason');
  }

  @IsTest
  static void anEndedChatActsForNobody() {
    List<StewardTestData.Household> households = StewardTestData.existingHouseholds();
    User customer = PortalTestData.createCustomers(households)[0];
    Id session = fakeSessionId(1);
    AgentSession.source = new Sessions()
      .add(session, 'Ended', WEB_CHAT, customer.Id);

    AgentSession.Identity identity = AgentSession.resolve(session);

    Assert.isNull(identity.accountId, 'Nothing is done in an ended chat');
    Assert.areEqual(AgentSession.SESSION_ENDED, identity.reasonCode, 'Reason');
  }

  @IsTest
  static void onlyThePortalsWebChatIsServed() {
    List<StewardTestData.Household> households = StewardTestData.existingHouseholds();
    User customer = PortalTestData.createCustomers(households)[0];
    Id session = fakeSessionId(1);
    AgentSession.source = new Sessions()
      .add(session, ACTIVE, 'Text', customer.Id);

    AgentSession.Identity identity = AgentSession.resolve(session);

    Assert.isNull(
      identity.accountId,
      'A text message session is not the portal'
    );
    Assert.areEqual(AgentSession.WRONG_CHANNEL, identity.reasonCode, 'Reason');
  }

  @IsTest
  static void anythingButAMessagingSessionIdIsRefusedUnread() {
    StewardTestData.Household household = StewardTestData.existingHouseholds()[0];
    Sessions sessions = new Sessions();
    AgentSession.source = sessions;
    Set<String> given = new Set<String>{
      null,
      '',
      '   ',
      'not an id',
      'DROP TABLE',
      String.valueOf(household.account.Id),
      String.valueOf(household.primaryContact.Id)
    };

    Map<String, AgentSession.Identity> identities = AgentSession.resolve(given);

    Assert.areEqual(
      given.size(),
      identities.size(),
      'An answer for every value'
    );
    for (String value : given) {
      AgentSession.Identity identity = identities.get(value);
      Assert.isNull(
        identity.accountId,
        'An account or contact ID typed into a chat names no household: ' +
        value
      );
      Assert.areEqual(AgentSession.NOT_VERIFIED, identity.reasonCode, value);
    }
    Assert.areEqual(0, sessions.loads, 'None of them is even looked up');
  }

  @IsTest
  static void aSessionThatDoesntExistHasNoHousehold() {
    Id session = fakeSessionId(1);

    // The real source: the org has no such session.
    AgentSession.Identity identity = AgentSession.resolve(session);

    Assert.isNull(identity.accountId, 'No session, no household');
    Assert.areEqual(AgentSession.NOT_VERIFIED, identity.reasonCode, 'Reason');
    Assert.areEqual(
      String.valueOf(session),
      identity.sessionId,
      'The ID as given'
    );
  }

  @IsTest
  static void aNullSetAnswersNothing() {
    Assert.isTrue(
      AgentSession.resolve((Set<String>) null).isEmpty(),
      'Nothing in, nothing out'
    );
  }

  @IsTest
  static void factsComeFromTheSessionAndItsMessagingUser() {
    Id session = fakeSessionId(1);
    Id user = UserInfo.getUserId();
    MessagingSession record = (MessagingSession) JSON.deserialize(
      '{"attributes":{"type":"MessagingSession"},"Id":"' +
        session +
        '","Status":"Active","ChannelType":"EmbeddedMessaging",' +
        '"MessagingEndUser":{"attributes":{"type":"MessagingEndUser"},' +
        '"AuthenticatedEndUserId":"' +
        user +
        '"}}',
      MessagingSession.class
    );

    AgentSession.SessionFacts facts = AgentSession.factsFrom(record);

    Assert.areEqual(session, facts.sessionId, 'Session ID');
    Assert.areEqual('Active', facts.status, 'Status');
    Assert.areEqual(WEB_CHAT, facts.channelType, 'Channel type');
    Assert.areEqual(user, facts.authenticatedUserId, 'Authenticated user');
  }

  @IsTest
  static void aSessionWithNoMessagingUserHasNoAuthenticatedUser() {
    MessagingSession record = (MessagingSession) JSON.deserialize(
      '{"attributes":{"type":"MessagingSession"},"Status":"Active","ChannelType":"EmbeddedMessaging"}',
      MessagingSession.class
    );

    Assert.isNull(
      AgentSession.factsFrom(record).authenticatedUserId,
      'No messaging user, no authenticated user'
    );
  }

  // A well-formed messaging session ID that no record has.
  private static Id fakeSessionId(Integer n) {
    String prefix = MessagingSession.SObjectType.getDescribe().getKeyPrefix();
    return Id.valueOf(prefix + String.valueOf(n).leftPad(12, '0'));
  }

  // Session facts set by the test, standing in for the org's messaging records.
  private class Sessions implements AgentSession.SessionSource {
    private Map<Id, AgentSession.SessionFacts> facts = new Map<Id, AgentSession.SessionFacts>();
    public Integer loads = 0;

    public Sessions add(
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
}
