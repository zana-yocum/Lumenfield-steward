/**
 * ST-08, ST-09, ST-10, S-21. Proves each button runs its own template for the record on the
 * page, and only after the checks: a household or billing dispute the user can see, and for a
 * follow-up, a contact attempt logged today. Proves a model failure comes back as a failure, and
 * that the follow-up email is addressed and signed here, with the model's text escaped. The model
 * is a stand-in: a test can't reach one.
 */
@IsTest
private class RepAssistantControllerTest {
  /** Records what it was asked and answers with fixed text, or fails. */
  private class StandInModel implements PromptRunner.Model {
    String text = 'Generated text.';
    Boolean fail = false;
    List<String> calls = new List<String>();

    /**
     * Records the request, then answers or fails.
     * @param templateName the template
     * @param inputName the template input
     * @param recordId the record
     * @return the fixed text
     */
    public String generate(String templateName, String inputName, Id recordId) {
      calls.add(templateName + '|' + inputName + '|' + recordId);
      if (fail) {
        throw new PromptRunner.PromptRunnerException(
          'Einstein is unavailable.'
        );
      }
      return text;
    }
  }

  @TestSetup
  static void createData() {
    List<StewardTestData.Household> households = StewardTestData.createHouseholds(
      2,
      StewardTestData.ACCOUNT_DELINQUENT
    );
    Billing_Statement__c statement = StewardTestData.statement(
      households[0],
      StewardTestData.monthStart(2),
      190,
      StewardTestData.STATEMENT_PAST_DUE
    );
    insert statement;
    StewardTestData.insertDispute(
      households[0],
      statement,
      'Payment Not Posted'
    );
    PortalTestData.insertDefaultReview(households[0]);
    insert new Task(
      WhatId = households[0].account.Id,
      Subject = 'Contact attempt: Promise Made',
      Contact_Outcome__c = 'Promise Made',
      Status = 'Completed',
      ActivityDate = Date.today()
    );
  }

  @IsTest
  static void briefingRunsItsTemplateForTheHousehold() {
    StandInModel model = useStandIn();
    Id accountId = household(0).Id;

    Test.startTest();
    RepAssistantController.Generated result = RepAssistantController.briefing(
      accountId
    );
    Test.stopTest();

    Assert.areEqual(StewardOutcome.COMPLETED, result.outcome, 'Completed');
    Assert.areEqual('Generated text.', result.text, 'The model\'s text');
    Assert.areEqual(
      new List<String>{
        RepAssistantController.BRIEFING_TEMPLATE +
        '|Input:Household|' +
        accountId
      },
      model.calls,
      'One generation, with the household as the template\'s input'
    );
  }

  @IsTest
  static void nothingRunsForAHouseholdTheUserCantSee() {
    StandInModel model = useStandIn();
    Id accountId = household(0).Id;
    User outsider = StewardTestData.createUserWithoutAccess();
    RepAssistantController.Generated briefing;
    RepAssistantController.FollowupEmail followup;

    Test.startTest();
    System.runAs(outsider) {
      briefing = RepAssistantController.briefing(accountId);
      followup = RepAssistantController.followupDraft(accountId);
    }
    Test.stopTest();

    Assert.areEqual(StewardOutcome.NOT_FOUND, briefing.reasonCode, 'Briefing');
    Assert.areEqual(StewardOutcome.NOT_FOUND, followup.reasonCode, 'Follow-up');
    Assert.isTrue(model.calls.isEmpty(), 'The model is never asked');
  }

  @IsTest
  static void aModelFailureComesBackAsAFailure() {
    StandInModel model = useStandIn();
    model.fail = true;
    Id accountId = household(0).Id;

    Test.startTest();
    RepAssistantController.Generated briefing = RepAssistantController.briefing(
      accountId
    );
    RepAssistantController.FollowupEmail followup = RepAssistantController.followupDraft(
      accountId
    );
    Test.stopTest();

    Assert.areEqual(StewardOutcome.FAILED, briefing.outcome, 'Briefing failed');
    Assert.areEqual(
      RepAssistantController.GENERATION_FAILED,
      briefing.reasonCode,
      'Reason'
    );
    Assert.areEqual(
      'Einstein is unavailable.',
      briefing.detail,
      'Detail for the rep'
    );
    Assert.isNull(briefing.text, 'No text');
    Assert.areEqual(
      StewardOutcome.FAILED,
      followup.outcome,
      'Follow-up failed'
    );
    Assert.isNull(followup.htmlBody, 'No email');
  }

  @IsTest
  static void disputeSummaryOnlyForABillingDispute() {
    StandInModel model = useStandIn();
    Case dispute = caseOf('Billing_Dispute');
    Case review = caseOf('Default_Review');

    Test.startTest();
    RepAssistantController.Generated summary = RepAssistantController.disputeSummary(
      dispute.Id
    );
    RepAssistantController.Generated refused = RepAssistantController.disputeSummary(
      review.Id
    );
    Test.stopTest();

    Assert.areEqual(
      StewardOutcome.COMPLETED,
      summary.outcome,
      'A dispute is summarized'
    );
    Assert.areEqual(
      StewardOutcome.NOT_FOUND,
      refused.reasonCode,
      'A review isn\'t'
    );
    Assert.areEqual(
      new List<String>{
        RepAssistantController.DISPUTE_SUMMARY_TEMPLATE +
        '|Input:Dispute|' +
        dispute.Id
      },
      model.calls,
      'One generation, for the dispute only'
    );
  }

  @IsTest
  static void noFollowupUntilTodaysAttemptIsLogged() {
    StandInModel model = useStandIn();

    Test.startTest();
    RepAssistantController.FollowupEmail email = RepAssistantController.followupDraft(
      household(1).Id
    );
    Test.stopTest();

    Assert.areEqual(StewardOutcome.DECLINED_POLICY, email.outcome, 'Declined');
    Assert.areEqual(
      RepAssistantController.NO_ATTEMPT_TODAY,
      email.reasonCode,
      'Why'
    );
    Assert.isTrue(model.calls.isEmpty(), 'The model is never asked');
  }

  @IsTest
  static void followupIsAddressedAndSignedHere() {
    StandInModel model = useStandIn();
    model.text = 'Thanks for talking with us today.\n\nYou promised <b>$190.00</b> by Friday.\nWe\'ll watch for it.';
    Account household = household(0);
    Contact recipient = [
      SELECT FirstName, Email
      FROM Contact
      WHERE AccountId = :household.Id
      LIMIT 1
    ];

    Test.startTest();
    RepAssistantController.FollowupEmail email = RepAssistantController.followupDraft(
      household.Id
    );
    Test.stopTest();

    Assert.areEqual(StewardOutcome.COMPLETED, email.outcome, 'Completed');
    Assert.areEqual(recipient.Email, email.toAddress, 'To the primary contact');
    Assert.areEqual(
      System.Label.Steward_Rep_Subject_Promise,
      email.subject,
      'Subject'
    );
    Assert.areEqual(
      '<p>' +
        String.format(
          System.Label.Steward_Rep_Greeting,
          new List<Object>{ recipient.FirstName }
        ) +
        '</p>' +
        '<p>Thanks for talking with us today.</p>' +
        '<p>' +
        'You promised <b>$190.00</b> by Friday.'.escapeHtml4() +
        '<br>' +
        'We\'ll watch for it.'.escapeHtml4() +
        '</p>' +
        '<p>' +
        System.Label.Steward_Rep_Signoff.escapeHtml4() +
        '<br>' +
        UserInfo.getName().escapeHtml4() +
        '<br>' +
        UserInfo.getOrganizationName().escapeHtml4() +
        '</p>',
      email.htmlBody,
      'Greeting, the model\'s paragraphs as escaped text, and the rep\'s sign-off'
    );
    Assert.isFalse(
      email.htmlBody.contains('<b>'),
      'The model\'s markup is never live'
    );
    Assert.areEqual(
      RepAssistantController.FOLLOWUP_TEMPLATE +
        '|Input:Household|' +
        household.Id,
      model.calls[0],
      'The follow-up template, for the household'
    );
  }

  @IsTest
  static void subjectsAndGreetingsFollowTheCall() {
    Assert.areEqual(
      System.Label.Steward_Rep_Subject_Missed,
      RepAssistantController.subjectFor('Left Voicemail'),
      'Nobody reached'
    );
    Assert.areEqual(
      System.Label.Steward_Rep_Subject_Call,
      RepAssistantController.subjectFor('Right Party Contact'),
      'Somebody reached'
    );
    Assert.areEqual(
      System.Label.Steward_Rep_Greeting_Plain,
      RepAssistantController.greeting(null),
      'No first name on record'
    );
  }

  private static StandInModel useStandIn() {
    StandInModel model = new StandInModel();
    PromptRunner.model = model;
    return model;
  }

  private static Account household(Integer index) {
    return [
      SELECT Id
      FROM Account
      WHERE Name LIKE 'Steward Test Household%'
      ORDER BY Name
    ][index];
  }

  private static Case caseOf(String recordType) {
    return [
      SELECT Id
      FROM Case
      WHERE RecordType.DeveloperName = :recordType
      LIMIT 1
    ];
  }
}
