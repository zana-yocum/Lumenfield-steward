/**
 * ST-10, S-20. Proves the follow-up data is grounded in the contact attempt the person logged
 * today, takes a promise's amount, date and status straight from the record, ignores yesterday's
 * attempts, leaves the customer's name and email out, and gives nothing for a household the
 * person can't see.
 */
@IsTest
private class FollowupDraftPromptTest {
  @TestSetup
  static void createData() {
    List<StewardTestData.Household> households = StewardTestData.createHouseholds(
      3,
      StewardTestData.ACCOUNT_DELINQUENT
    );
    insert new List<Billing_Statement__c>{
      StewardTestData.statement(
        households[0],
        StewardTestData.monthStart(2),
        190,
        StewardTestData.STATEMENT_PAST_DUE
      )
    };
    // The Log Contact Attempt flow's two saves for a promise: the attempt, then the promise.
    insert attempt(households[0].account.Id, 'Promise Made');
    insert StewardTestData.promise(
      households[0],
      Date.today().addDays(10),
      190,
      'Active'
    );
    insert attempt(households[1].account.Id, 'Left Voicemail');
  }

  @IsTest
  static void aPromiseMadeTodayComesFromItsRecord() {
    StewardTestData.Household promised = household(0);

    Test.startTest();
    String text = FollowupDraftPrompt.build(new Set<Id>{ promised.account.Id })
      .get(promised.account.Id);
    Test.stopTest();

    Promise_to_Pay__c promise = [
      SELECT Status__c
      FROM Promise_to_Pay__c
      WHERE Account__c = :promised.account.Id
    ];
    Account household = [
      SELECT Past_Due_Balance__c
      FROM Account
      WHERE Id = :promised.account.Id
    ];
    Assert.isTrue(
      text.contains('Today: ' + PromptFormat.day(Date.today())),
      text
    );
    Assert.isTrue(
      text.contains('Outcome of today\'s contact attempt: Promise Made'),
      text
    );
    Assert.isTrue(
      text.contains(
        'Promise made today: $190.00 by ' +
          PromptFormat.day(Date.today().addDays(10)) +
          ', status ' +
          promise.Status__c
      ),
      text
    );
    Assert.isTrue(
      text.contains(
        'Past-due balance: ' + PromptFormat.money(household.Past_Due_Balance__c)
      ),
      text
    );
    Assert.isTrue(text.contains('Do Not Contact: No'), text);
    Assert.isFalse(text.contains(promised.primaryContact.LastName), 'No name');
    Assert.isFalse(
      text.contains(promised.primaryContact.Email),
      'No email address'
    );
    Assert.isFalse(text.contains('Rep notes'), 'The rep\'s notes stay out');
  }

  @IsTest
  static void otherOutcomesHaveNoPromiseLine() {
    StewardTestData.Household voicemail = household(1);

    Test.startTest();
    String text = FollowupDraftPrompt.build(new Set<Id>{ voicemail.account.Id })
      .get(voicemail.account.Id);
    Test.stopTest();

    Assert.isTrue(
      text.contains('Outcome of today\'s contact attempt: Left Voicemail'),
      text
    );
    Assert.isFalse(text.contains('Promise made today'), text);
  }

  @IsTest
  static void onlyAnAttemptLoggedTodayCounts() {
    StewardTestData.Household quiet = household(2);
    Task yesterday = attempt(quiet.account.Id, 'Right Party Contact');
    insert yesterday;
    Test.setCreatedDate(yesterday.Id, Datetime.now().addDays(-1));

    Test.startTest();
    Task found = FollowupDraftPrompt.latestAttemptToday(quiet.account.Id);
    String text = FollowupDraftPrompt.build(new Set<Id>{ quiet.account.Id })
      .get(quiet.account.Id);
    Test.stopTest();

    Assert.isNull(found, 'Yesterday\'s attempt doesn\'t ground today\'s draft');
    Assert.isTrue(
      text.contains('Outcome of today\'s contact attempt: none logged'),
      text
    );
    Assert.areEqual(
      'Promise Made',
      FollowupDraftPrompt.latestAttemptToday(household(0).account.Id)
        .Contact_Outcome__c,
      'Today\'s attempt is found'
    );
  }

  @IsTest
  static void someoneWhoCantSeeTheHouseholdGetsNothing() {
    StewardTestData.Household promised = household(0);
    User outsider = StewardTestData.createUserWithoutAccess();
    FollowupDraftPrompt.Request request = new FollowupDraftPrompt.Request();
    request.Household = new Account(Id = promised.account.Id);
    List<FollowupDraftPrompt.Response> responses;
    Task attemptSeen;

    Test.startTest();
    System.runAs(outsider) {
      responses = FollowupDraftPrompt.getPrompt(
        new List<FollowupDraftPrompt.Request>{ request }
      );
      attemptSeen = FollowupDraftPrompt.latestAttemptToday(promised.account.Id);
    }
    Test.stopTest();

    Assert.areEqual(
      FollowupDraftPrompt.NO_ACCESS,
      responses[0].Prompt,
      'Nothing'
    );
    Assert.isNull(attemptSeen, 'And no attempt to draft from');
  }

  @IsTest
  static void oneResponsePerRequestInOrder() {
    List<FollowupDraftPrompt.Request> requests = new List<FollowupDraftPrompt.Request>();
    for (Id accountId : new List<Id>{ household(1).account.Id, null }) {
      FollowupDraftPrompt.Request request = new FollowupDraftPrompt.Request();
      request.Household = accountId == null
        ? null
        : new Account(Id = accountId);
      requests.add(request);
    }

    Test.startTest();
    List<FollowupDraftPrompt.Response> responses = FollowupDraftPrompt.getPrompt(
      requests
    );
    Test.stopTest();

    Assert.isTrue(responses[0].Prompt.contains('Left Voicemail'), 'First');
    Assert.areEqual(
      FollowupDraftPrompt.NO_ACCESS,
      responses[1].Prompt,
      'No household'
    );
  }

  private static Task attempt(Id accountId, String outcome) {
    return new Task(
      WhatId = accountId,
      Subject = 'Contact attempt: ' + outcome,
      Contact_Outcome__c = outcome,
      Status = 'Completed',
      ActivityDate = Date.today(),
      Description = 'Rep notes stay out of the draft.'
    );
  }

  private static StewardTestData.Household household(Integer index) {
    return StewardTestData.existingHouseholds()[index];
  }
}
