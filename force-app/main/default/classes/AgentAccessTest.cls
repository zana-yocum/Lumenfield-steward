/**
 * S-01, ST-12, S-07, S-14. Runs the agent's actions the way the agent will run them: as a user on
 * the Einstein Agent User profile, whose only access is PS_Steward_Agent and what the Steward Agent
 * group is given. Every action answers a logged-in customer in full, so that access is enough; and
 * with every household shared to it, the agent still acts only for the customer behind the chat.
 * If an action ever needs more access, this test fails first.
 *
 * The group gets here, by hand, exactly what the two sharing rules give it: Edit on households with
 * Read on their cases, and Read on agreements. A check-only deployment doesn't apply sharing rules
 * it brings, and these tests make their own records, so the rules themselves are checked in the org
 * after each release (docs/security-model.md).
 *
 * The first household has three statements, the last one after its agreement's first anniversary
 * (the escalator), two of them past due, and was promised two covered payments at signing. The
 * second household has one past-due statement.
 */
@IsTest
private class AgentAccessTest {
  private static final String AGENT_PROFILE = 'Einstein Agent User';
  private static final String AGENT_PERMISSION_SET = 'PS_Steward_Agent';
  private static final String AGENT_GROUP = 'Steward_Agent';
  private static final String PAYMENT_NOT_POSTED = 'Payment Not Posted';

  @TestSetup
  static void createData() {
    PortalTestData.giveRunningUserARole();
    List<StewardTestData.Household> households = StewardTestData.createHouseholds(
      2,
      StewardTestData.ACCOUNT_DELINQUENT
    );
    Date anniversary = StewardTestData.firstAnniversary();
    insert new List<Billing_Statement__c>{
      StewardTestData.statement(
        households[0],
        anniversary.addMonths(-2),
        120.00,
        StewardTestData.STATEMENT_PAID
      ),
      StewardTestData.statement(
        households[0],
        anniversary.addMonths(-1),
        120.00,
        StewardTestData.STATEMENT_PAST_DUE
      ),
      StewardTestData.statement(
        households[0],
        anniversary,
        123.48,
        StewardTestData.STATEMENT_PAST_DUE
      ),
      StewardTestData.statement(
        households[1],
        StewardTestData.monthStart(1),
        120.00,
        StewardTestData.STATEMENT_PAST_DUE
      )
    };
    Opportunity deal = StewardTestData.deal(households[0]);
    insert deal;
    insert StewardTestData.commitment(
      deal,
      'Payment Coverage',
      240.00,
      2,
      'Lumenfield covers the first two monthly payments.',
      'Recorded'
    );
  }

  @IsTest
  static void theAgentReadsItsCustomersHouseholdInFull() {
    List<StewardTestData.Household> households = StewardTestData.existingHouseholds();
    AgentTestSessions sessions = chatsFor(households);
    User agent = createAgentUser();

    GetAccountSummaryAction.Output summary;
    GetCommitmentsAction.Output commitments;
    ExplainStatementAction.Output explained;
    GetDisputeReasonsAction.Output reasons;
    GetDisputeStatusAction.Output disputes;
    System.runAs(agent) {
      Test.startTest();
      summary = GetAccountSummaryAction.run(
        new List<GetAccountSummaryAction.Input>{ summaryInput(sessions) }
      )[0];
      commitments = GetCommitmentsAction.run(
        new List<GetCommitmentsAction.Input>{ commitmentsInput(sessions) }
      )[0];
      explained = ExplainStatementAction.run(
        new List<ExplainStatementAction.Input>{
          explainInput(sessions.id(1), null)
        }
      )[0];
      reasons = GetDisputeReasonsAction.run(
        new List<GetDisputeReasonsAction.Input>{ reasonsInput(sessions) }
      )[0];
      disputes = GetDisputeStatusAction.run(
        new List<GetDisputeStatusAction.Input>{ statusInput(sessions) }
      )[0];
      Test.stopTest();
    }

    assertCompleted('Get Account Summary', summary.outcome);
    Assert.areEqual(
      pastDueOf(households[0]),
      summary.pastDueBalance,
      'The household\'s own past-due balance'
    );
    Assert.areEqual(3, summary.statements.size(), 'Every statement');
    assertCompleted('Get Commitments', commitments.outcome);
    Assert.areEqual(1, commitments.commitments.size(), 'The commitment');
    assertCompleted('Explain Statement', explained.outcome);
    Assert.isTrue(
      hasReason(explained, StatementExplanationService.ESCALATOR),
      'The escalator, read from the agreement: ' + JSON.serialize(explained)
    );
    assertCompleted('Get Dispute Reasons', reasons.outcome);
    Assert.isFalse(reasons.reasons.isEmpty(), 'The reasons');
    assertCompleted('Get Dispute Status', disputes.outcome);
  }

  @IsTest
  static void theAgentSetsUpAnArrangementOpensADisputeAndHandsOff() {
    List<StewardTestData.Household> households = StewardTestData.existingHouseholds();
    AgentTestSessions sessions = chatsFor(households);
    User agent = createAgentUser();
    Decimal pastDue = pastDueOf(households[0]);
    Date nextWeek = Date.today().addDays(7);
    Id latest = latestStatementOf(households[0]);

    CheckPaymentArrangementAction.Output checked;
    CreatePaymentArrangementAction.Output created;
    OpenDisputeAction.Output opened;
    RecordHandoffAction.Output handedOff;
    System.runAs(agent) {
      Test.startTest();
      checked = CheckPaymentArrangementAction.run(
        new List<CheckPaymentArrangementAction.Input>{
          checkInput(sessions.id(1), nextWeek, pastDue)
        }
      )[0];
      created = CreatePaymentArrangementAction.run(
        new List<CreatePaymentArrangementAction.Input>{
          createInput(sessions.id(1), nextWeek, pastDue)
        }
      )[0];
      opened = OpenDisputeAction.run(
        new List<OpenDisputeAction.Input>{
          disputeInput(sessions.id(1), latest)
        }
      )[0];
      handedOff = RecordHandoffAction.run(
        new List<RecordHandoffAction.Input>{ handoffInput(sessions.id(1)) }
      )[0];
      Test.stopTest();
    }

    assertCompleted('Check Payment Arrangement', checked.outcome);
    Assert.areEqual(
      PaymentArrangementService.ELIGIBLE,
      checked.reasonCode,
      'Eligible'
    );
    assertCompleted('Create Payment Arrangement', created.outcome);
    Assert.areEqual(
      'Active',
      [
        SELECT Status__c
        FROM Promise_to_Pay__c
        WHERE Account__c = :households[0].account.Id
        WITH SYSTEM_MODE
      ]
      .Status__c,
      'The promise is saved through Accord\'s flow, Active'
    );
    assertCompleted('Open Dispute', opened.outcome);
    Assert.isNotNull(opened.caseNumber, 'The case number, read back');
    Assert.areEqual(StewardOutcome.HANDOFF, handedOff.outcome, 'Handed off');
    Assert.isNotNull(handedOff.reference, 'The log number for the person');
  }

  @IsTest
  static void everyHouseholdIsSharedButTheAgentActsOnlyForTheCustomerInTheChat() {
    List<StewardTestData.Household> households = StewardTestData.existingHouseholds();
    AgentTestSessions sessions = chatsFor(households);
    User agent = createAgentUser();
    Account organization = new Account(
      Name = 'Steward Test Organization',
      RecordTypeId = Schema.SObjectType.Account
        .getRecordTypeInfosByDeveloperName()
        .get('Organization')
        .getRecordTypeId()
    );
    insert organization;
    Id someoneElses = latestStatementOf(households[0]);

    Integer householdsSeen;
    Integer organizationsSeen;
    ExplainStatementAction.Output output;
    System.runAs(agent) {
      householdsSeen = [
        SELECT COUNT()
        FROM Account
        WHERE Id = :households[0].account.Id
        WITH USER_MODE
      ];
      organizationsSeen = [
        SELECT COUNT()
        FROM Account
        WHERE Id = :organization.Id
        WITH USER_MODE
      ];
      // The second customer's chat, asking about the first household's statement.
      output = ExplainStatementAction.run(
        new List<ExplainStatementAction.Input>{
          explainInput(sessions.id(2), someoneElses)
        }
      )[0];
    }

    Assert.areEqual(
      1,
      householdsSeen,
      'The agent user can see every household'
    );
    Assert.areEqual(0, organizationsSeen, 'Organization accounts stay out');
    Assert.areEqual(StewardOutcome.DECLINED_POLICY, output.outcome, 'Declined');
    Assert.areEqual(
      StewardOutcome.NOT_FOUND,
      output.reasonCode,
      'Another household\'s statement is not found from this chat'
    );
    Assert.isNull(output.statement, 'Nothing about it comes back');
  }

  @IsTest
  static void theAgentUserCantSetACasesAccountSoDisputesStayAnException() {
    List<StewardTestData.Household> households = StewardTestData.existingHouseholds();
    User agent = createAgentUser();

    SObjectAccessDecision decision;
    System.runAs(agent) {
      decision = Security.stripInaccessible(
        AccessType.CREATABLE,
        new List<Case>{
          new Case(
            AccountId = households[0].account.Id,
            Subject = 'Billing dispute'
          )
        }
      );
    }

    Set<String> removed = decision.getRemovedFields().get('Case');
    Assert.isTrue(
      removed != null && removed.contains('AccountId'),
      'The agent user can\'t set a case\'s account, so the dispute insert stays in system mode (S-14): ' +
      removed
    );
    Assert.isFalse(
      removed.contains('Subject'),
      'It can set the dispute\'s own fields'
    );
  }

  /**
   * A user like the agent user: the Einstein Agent User profile, which grants nothing, plus the
   * agent's permission set and group, and the group's sharing.
   * @return the user
   */
  private static User createAgentUser() {
    String unique = String.valueOf(Math.abs(Crypto.getRandomInteger()));
    User agent = new User(
      Alias = 'stwagent',
      Email = 'steward.agent.' + unique + '@example.com',
      EmailEncodingKey = 'UTF-8',
      LastName = 'Steward Agent',
      LanguageLocaleKey = 'en_US',
      LocaleSidKey = 'en_US',
      ProfileId = [SELECT Id FROM Profile WHERE Name = :AGENT_PROFILE LIMIT 1]
      .Id,
      TimeZoneSidKey = 'America/New_York',
      Username = 'steward.agent.' + unique + '@example.com'
    );
    Id agentGroup = [
      SELECT Id
      FROM Group
      WHERE DeveloperName = :AGENT_GROUP AND Type = 'Regular'
      LIMIT 1
    ]
    .Id;
    shareLikeTheRules(StewardTestData.existingHouseholds(), agentGroup);
    // Users, permission set assignments and group members are setup records: their own context.
    System.runAs(new User(Id = UserInfo.getUserId())) {
      insert agent;
      insert new PermissionSetAssignment(
        AssigneeId = agent.Id,
        PermissionSetId = [
          SELECT Id
          FROM PermissionSet
          WHERE Name = :AGENT_PERMISSION_SET
          LIMIT 1
        ]
        .Id
      );
      insert new GroupMember(GroupId = agentGroup, UserOrGroupId = agent.Id);
    }
    return agent;
  }

  /**
   * What Households_to_Steward_Agent and Agreements_to_Steward_Agent give the group.
   * @param households the test's households
   * @param agentGroup the Steward Agent group
   */
  private static void shareLikeTheRules(
    List<StewardTestData.Household> households,
    Id agentGroup
  ) {
    List<SObject> shares = new List<SObject>();
    Set<Id> accountIds = new Set<Id>();
    for (StewardTestData.Household household : households) {
      accountIds.add(household.account.Id);
      shares.add(
        new AccountShare(
          AccountId = household.account.Id,
          UserOrGroupId = agentGroup,
          AccountAccessLevel = 'Edit',
          CaseAccessLevel = 'Read',
          OpportunityAccessLevel = 'None'
        )
      );
    }
    for (ServiceContract agreement : [
      SELECT Id
      FROM ServiceContract
      WHERE AccountId IN :accountIds
      WITH SYSTEM_MODE
    ]) {
      shares.add(
        new ServiceContractShare(
          ParentId = agreement.Id,
          UserOrGroupId = agentGroup,
          AccessLevel = 'Read'
        )
      );
    }
    insert shares;
  }

  /**
   * Chat 1 is the first household's customer and chat 2 the second's.
   * @param households the test's households
   * @return the sessions, installed
   */
  private static AgentTestSessions chatsFor(
    List<StewardTestData.Household> households
  ) {
    List<User> customers = PortalTestData.createCustomers(households);
    return new AgentTestSessions()
      .chat(1, customers[0].Id)
      .chat(2, customers[1].Id)
      .install();
  }

  /**
   * Fails with the logged details of the last failure, so a missing permission names itself.
   * @param action the action's label
   * @param outcome what it answered
   */
  private static void assertCompleted(String action, String outcome) {
    if (outcome == StewardOutcome.COMPLETED) {
      return;
    }
    List<Agent_Action_Log__c> failures = [
      SELECT Action__c, Reason_Code__c, Details__c
      FROM Agent_Action_Log__c
      WHERE Outcome__c != 'Completed'
      WITH SYSTEM_MODE
      ORDER BY Name DESC
      LIMIT 1
    ];
    Assert.fail(
      action +
        ' answered ' +
        outcome +
        (failures.isEmpty() ? '' : ': ' + JSON.serialize(failures[0]))
    );
  }

  private static Decimal pastDueOf(StewardTestData.Household household) {
    return [
      SELECT Past_Due_Balance__c
      FROM Account
      WHERE Id = :household.account.Id
      WITH SYSTEM_MODE
    ]
    .Past_Due_Balance__c;
  }

  private static Id latestStatementOf(StewardTestData.Household household) {
    return [
      SELECT Id
      FROM Billing_Statement__c
      WHERE Account__c = :household.account.Id
      WITH SYSTEM_MODE
      ORDER BY Statement_Date__c DESC
      LIMIT 1
    ]
    .Id;
  }

  private static Boolean hasReason(
    ExplainStatementAction.Output output,
    String code
  ) {
    if (output.reasons == null) {
      return false;
    }
    for (StatementExplanationService.Reason reason : output.reasons) {
      if (reason.code == code) {
        return true;
      }
    }
    return false;
  }

  private static GetAccountSummaryAction.Input summaryInput(
    AgentTestSessions sessions
  ) {
    GetAccountSummaryAction.Input input = new GetAccountSummaryAction.Input();
    input.sessionId = sessions.id(1);
    return input;
  }

  private static GetCommitmentsAction.Input commitmentsInput(
    AgentTestSessions sessions
  ) {
    GetCommitmentsAction.Input input = new GetCommitmentsAction.Input();
    input.sessionId = sessions.id(1);
    return input;
  }

  private static GetDisputeReasonsAction.Input reasonsInput(
    AgentTestSessions sessions
  ) {
    GetDisputeReasonsAction.Input input = new GetDisputeReasonsAction.Input();
    input.sessionId = sessions.id(1);
    return input;
  }

  private static GetDisputeStatusAction.Input statusInput(
    AgentTestSessions sessions
  ) {
    GetDisputeStatusAction.Input input = new GetDisputeStatusAction.Input();
    input.sessionId = sessions.id(1);
    return input;
  }

  private static ExplainStatementAction.Input explainInput(
    Id sessionId,
    Id statementId
  ) {
    ExplainStatementAction.Input input = new ExplainStatementAction.Input();
    input.sessionId = sessionId;
    input.statementId = statementId;
    return input;
  }

  private static CheckPaymentArrangementAction.Input checkInput(
    Id sessionId,
    Date promiseDate,
    Decimal amount
  ) {
    CheckPaymentArrangementAction.Input input = new CheckPaymentArrangementAction.Input();
    input.sessionId = sessionId;
    input.promiseDate = promiseDate;
    input.amount = amount;
    return input;
  }

  private static CreatePaymentArrangementAction.Input createInput(
    Id sessionId,
    Date promiseDate,
    Decimal amount
  ) {
    CreatePaymentArrangementAction.Input input = new CreatePaymentArrangementAction.Input();
    input.sessionId = sessionId;
    input.promiseDate = promiseDate;
    input.amount = amount;
    return input;
  }

  private static OpenDisputeAction.Input disputeInput(
    Id sessionId,
    Id statementId
  ) {
    OpenDisputeAction.Input input = new OpenDisputeAction.Input();
    input.sessionId = sessionId;
    input.statementId = statementId;
    input.reason = PAYMENT_NOT_POSTED;
    return input;
  }

  private static RecordHandoffAction.Input handoffInput(Id sessionId) {
    RecordHandoffAction.Input input = new RecordHandoffAction.Input();
    input.sessionId = sessionId;
    input.reasonCode = RecordHandoffAction.CUSTOMER_ASKED;
    input.summary = 'Wants to talk about the escalator with a person.';
    return input;
  }
}
