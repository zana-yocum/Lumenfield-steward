/**
 * ST-11, ST-12, NFR-07. Proves the plumbing every agent action shares (AgentActions.Calls), at the
 * edges no action's own tests reach: a chat with no logged-in customer behind it is declined before
 * anything is read, only a blank or a well-formed ID goes on to a service, an exception fails every
 * request that reached the service even one it had already answered, a request the service never
 * answers fails, and each failure gets the log's number to quote.
 */
@IsTest
private class AgentActionsTest {
  private static final String ACTION = 'AgentActionsTest';

  @TestSetup
  static void createData() {
    PortalTestData.giveRunningUserARole();
    StewardTestData.createHouseholds(2, StewardTestData.ACCOUNT_DELINQUENT);
  }

  @IsTest
  static void onlyARequestWithAVerifiedHouseholdIsSentOn() {
    AgentTestSessions sessions = sessionsForTwoCustomersAndAnAnonymousChat();
    AgentActions.Calls calls = new AgentActions.Calls(
      ACTION,
      new List<String>{ idOf(sessions, 1), idOf(sessions, 3) }
    );
    StewardOutcome.Result anonymous = new StewardOutcome.Result();

    Boolean customerSent = calls.begin(0, new StewardOutcome.Result(), 'One');
    Boolean anonymousSent = calls.begin(1, anonymous, 'Two');
    calls.serve(1, completed());

    Assert.isTrue(customerSent, 'A logged-in customer\'s request goes on');
    Assert.isFalse(anonymousSent, 'An anonymous chat\'s request does not');
    Assert.areEqual(
      StewardOutcome.DECLINED_POLICY,
      anonymous.outcome,
      'Declined, even when a service answer is handed in for it'
    );
    Assert.areEqual(AgentSession.NOT_VERIFIED, anonymous.reasonCode, 'Reason');
    Assert.isNotNull(calls.household(0), 'The customer\'s household');
    Assert.isNull(calls.household(1), 'No household behind the anonymous chat');
    Assert.areEqual(
      new Set<Id>{ calls.household(0) },
      calls.households(),
      'Only the verified household is read'
    );
  }

  @IsTest
  static void onlyABlankOrAWellFormedIdGoesOn() {
    AgentTestSessions sessions = sessionsForTwoCustomersAndAnAnonymousChat();
    String customer = idOf(sessions, 1);
    AgentActions.Calls calls = new AgentActions.Calls(
      ACTION,
      new List<String>{ customer, customer, customer, idOf(sessions, 3) }
    );
    List<StewardOutcome.Result> blanks = new List<StewardOutcome.Result>();
    for (Integer i = 0; i < 4; i++) {
      blanks.add(new StewardOutcome.Result());
      calls.begin(i, blanks[i], 'Request ' + i);
    }

    Assert.isTrue(calls.acceptsId(0, ' '), 'Blank: the service decides');
    Assert.isTrue(
      calls.acceptsId(1, String.valueOf(calls.household(1))),
      'A well-formed ID, which the service looks for in the household'
    );
    Assert.isFalse(calls.acceptsId(2, 'my last bill'), 'Words are not an ID');
    Assert.isFalse(
      calls.acceptsId(3, null),
      'A declined request stays declined'
    );
    Assert.areEqual(
      StewardOutcome.NOT_FOUND,
      blanks[2].reasonCode,
      'Not found, and nothing guessed'
    );
    Assert.areEqual(
      AgentSession.NOT_VERIFIED,
      blanks[3].reasonCode,
      'The first reason stands'
    );
    Assert.areEqual(
      1,
      calls.households().size(),
      'Two requests still waiting, for one household'
    );
  }

  @IsTest
  static void anExceptionFailsEveryRequestSentEvenOneAlreadyAnswered() {
    AgentTestSessions sessions = sessionsForTwoCustomersAndAnAnonymousChat();
    AgentActions.Calls calls = new AgentActions.Calls(
      ACTION,
      new List<String>{
        idOf(sessions, 1),
        idOf(sessions, 2),
        idOf(sessions, 3)
      }
    );
    for (Integer i = 0; i < 3; i++) {
      calls.begin(i, new StewardOutcome.Result(), 'Request ' + i);
    }
    StewardOutcome.Result answered = completed();
    calls.serve(0, answered);

    calls.fail(new DmlException('Simulated failure'));
    List<StewardOutcome.Result> answers = calls.finish();

    for (Integer i = 0; i < 2; i++) {
      Assert.areEqual(
        StewardOutcome.FAILED,
        answers[i].outcome,
        'Failed: ' + i
      );
      Assert.areEqual(
        AgentActions.UNEXPECTED_ERROR,
        answers[i].reasonCode,
        'Reason: ' + i
      );
      Assert.isNotNull(answers[i].reference, 'A number to quote: ' + i);
    }
    Assert.areEqual(
      StewardOutcome.COMPLETED,
      answered.outcome,
      'The answer from before the failure is set aside, not passed on'
    );
    Assert.areEqual(
      StewardOutcome.DECLINED_POLICY,
      answers[2].outcome,
      'A request declined before the call keeps its decline'
    );
    Assert.isNull(answers[2].reference, 'Only a failure gets a reference');

    List<Agent_Action_Log__c> logs = [
      SELECT Details__c, Conversation_Id__c
      FROM Agent_Action_Log__c
      WITH SYSTEM_MODE
      ORDER BY Name
    ];
    Assert.areEqual(3, logs.size(), 'One log record per request');
    Assert.isTrue(
      logs[0].Details__c.contains('Simulated failure'),
      'The error is in the log: ' + logs[0].Details__c
    );
    Assert.areEqual(
      idOf(sessions, 1),
      logs[0].Conversation_Id__c,
      'The conversation is the session'
    );
  }

  @IsTest
  static void aRequestTheServiceNeverAnsweredFails() {
    AgentTestSessions sessions = sessionsForTwoCustomersAndAnAnonymousChat();
    AgentActions.Calls calls = new AgentActions.Calls(
      ACTION,
      new List<String>{ idOf(sessions, 1) }
    );
    calls.begin(0, new StewardOutcome.Result(), 'Asked');
    calls.serve(0, null);

    StewardOutcome.Result answer = calls.finish()[0];

    Assert.areEqual(StewardOutcome.FAILED, answer.outcome, 'Failed');
    Assert.isNotNull(answer.reference, 'A number to quote');
    Assert.areEqual(
      AgentActions.NO_ANSWER,
      [SELECT Details__c FROM Agent_Action_Log__c WITH SYSTEM_MODE].Details__c,
      'Why, in the log'
    );
  }

  @IsTest
  static void theServicesOwnFailureMessageGoesToTheLog() {
    AgentTestSessions sessions = sessionsForTwoCustomersAndAnAnonymousChat();
    AgentActions.Calls calls = new AgentActions.Calls(
      ACTION,
      new List<String>{ idOf(sessions, 1) }
    );
    calls.begin(0, new StewardOutcome.Result(), 'Asked');
    StewardOutcome.Result saveFailed = new StewardOutcome.Result();
    saveFailed.setOutcome(StewardOutcome.FAILED, 'SAVE_FAILED');

    calls.serve(0, saveFailed);
    calls.logFailureDetail(0, 'FIELD_CUSTOM_VALIDATION_EXCEPTION: too low');
    StewardOutcome.Result answer = calls.finish()[0];

    Assert.areEqual('SAVE_FAILED', answer.reasonCode, 'The service\'s reason');
    Assert.isNotNull(answer.reference, 'A number to quote');
    Assert.areEqual(
      'FIELD_CUSTOM_VALIDATION_EXCEPTION: too low',
      [SELECT Details__c FROM Agent_Action_Log__c WITH SYSTEM_MODE].Details__c,
      'The platform\'s message, in the log only'
    );
  }

  /**
   * Sessions 1 and 2 are the two customers' chats; session 3 is an anonymous chat.
   * @return the sessions, installed
   */
  private static AgentTestSessions sessionsForTwoCustomersAndAnAnonymousChat() {
    List<User> customers = PortalTestData.createCustomers(
      StewardTestData.existingHouseholds()
    );
    return new AgentTestSessions()
      .chat(1, customers[0].Id)
      .chat(2, customers[1].Id)
      .chat(3, null)
      .install();
  }

  private static String idOf(AgentTestSessions sessions, Integer n) {
    return String.valueOf(sessions.id(n));
  }

  private static StewardOutcome.Result completed() {
    StewardOutcome.Result result = new StewardOutcome.Result();
    result.setOutcome(StewardOutcome.COMPLETED, null);
    return result;
  }
}
