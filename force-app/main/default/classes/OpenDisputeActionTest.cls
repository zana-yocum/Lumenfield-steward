/**
 * ST-06, ST-12, GR-02, GR-05, GR-06. Proves a confirmed dispute opens on the logged-in customer's
 * own statement and comes back with its case number and evidence; that another household's
 * statement, or words in place of a statement ID, open nothing; and that a chat with no customer
 * behind it can't open a case.
 */
@IsTest
private class OpenDisputeActionTest {
  private static final String PAYMENT_NOT_POSTED = 'Payment Not Posted';

  @TestSetup
  static void createData() {
    PortalTestData.giveRunningUserARole();
    List<StewardTestData.Household> households = StewardTestData.createHouseholds(
      2,
      StewardTestData.ACCOUNT_DELINQUENT
    );
    insert new List<Billing_Statement__c>{
      StewardTestData.statement(
        households[0],
        StewardTestData.monthStart(1),
        120.00,
        StewardTestData.STATEMENT_PAST_DUE
      ),
      StewardTestData.statement(
        households[1],
        StewardTestData.monthStart(1),
        120.00,
        StewardTestData.STATEMENT_PAST_DUE
      )
    };
    insert StewardTestData.entitlement(households[0]);
  }

  @IsTest
  static void opensADisputeOnTheCustomersOwnStatement() {
    List<StewardTestData.Household> households = StewardTestData.existingHouseholds();
    List<User> customers = PortalTestData.createCustomers(households);
    AgentTestSessions sessions = new AgentTestSessions()
      .chat(1, customers[0].Id)
      .install();
    Billing_Statement__c statement = statementOf(households[0].account.Id);

    Test.startTest();
    OpenDisputeAction.Output output = OpenDisputeAction.run(
      new List<OpenDisputeAction.Input>{
        input(sessions.id(1), statement.Id, PAYMENT_NOT_POSTED)
      }
    )[0];
    Test.stopTest();

    Assert.areEqual(
      StewardOutcome.COMPLETED,
      output.outcome,
      'Completed: ' + output.reasonCode
    );
    Assert.isNotNull(output.caseNumber, 'A case number to quote');
    Assert.areEqual(PAYMENT_NOT_POSTED, output.reason, 'The reason');
    Assert.isFalse(output.evidence.isEmpty(), 'With the evidence to send');
    Case dispute = [
      SELECT AccountId, Disputed_Statement__c, Dispute_Reason__c
      FROM Case
      WHERE CaseNumber = :output.caseNumber
      WITH SYSTEM_MODE
    ];
    Assert.areEqual(
      households[0].account.Id,
      dispute.AccountId,
      'On the logged-in customer\'s household'
    );
    Assert.areEqual(statement.Id, dispute.Disputed_Statement__c, 'Statement');
  }

  @IsTest
  static void anotherHouseholdsStatementOpensNothing() {
    List<StewardTestData.Household> households = StewardTestData.existingHouseholds();
    List<User> customers = PortalTestData.createCustomers(households);
    AgentTestSessions sessions = new AgentTestSessions()
      .chat(2, customers[1].Id)
      .install();
    Billing_Statement__c someoneElses = statementOf(households[0].account.Id);

    OpenDisputeAction.Output output = OpenDisputeAction.run(
      new List<OpenDisputeAction.Input>{
        input(sessions.id(2), someoneElses.Id, PAYMENT_NOT_POSTED)
      }
    )[0];

    Assert.areEqual(
      StewardOutcome.DECLINED_POLICY,
      output.outcome,
      'Declined: ' + output.reasonCode
    );
    Assert.areEqual(StewardOutcome.NOT_FOUND, output.reasonCode, 'Reason');
    Assert.areEqual(
      0,
      [SELECT COUNT() FROM Case WITH SYSTEM_MODE],
      'No case opened'
    );
  }

  @IsTest
  static void wordsInPlaceOfAStatementIdOpenNothing() {
    List<User> customers = PortalTestData.createCustomers(
      StewardTestData.existingHouseholds()
    );
    AgentTestSessions sessions = new AgentTestSessions()
      .chat(1, customers[0].Id)
      .install();

    OpenDisputeAction.Output output = OpenDisputeAction.run(
      new List<OpenDisputeAction.Input>{
        input(sessions.id(1), 'last month\'s bill', PAYMENT_NOT_POSTED)
      }
    )[0];

    Assert.areEqual(StewardOutcome.NOT_FOUND, output.reasonCode, 'Reason');
    Assert.areEqual(
      0,
      [SELECT COUNT() FROM Case WITH SYSTEM_MODE],
      'No case opened'
    );
  }

  @IsTest
  static void aChatWithNoCustomerBehindItOpensNothing() {
    List<StewardTestData.Household> households = StewardTestData.existingHouseholds();
    AgentTestSessions sessions = new AgentTestSessions()
      .chat(1, null)
      .install();

    OpenDisputeAction.Output output = OpenDisputeAction.run(
      new List<OpenDisputeAction.Input>{
        input(
          sessions.id(1),
          statementOf(households[0].account.Id).Id,
          PAYMENT_NOT_POSTED
        )
      }
    )[0];

    Assert.areEqual(StewardOutcome.DECLINED_POLICY, output.outcome, 'Declined');
    Assert.areEqual(AgentSession.NOT_VERIFIED, output.reasonCode, 'Reason');
    Assert.areEqual(
      0,
      [SELECT COUNT() FROM Case WITH SYSTEM_MODE],
      'No case opened'
    );
  }

  @IsTest
  static void aFailureOpensNothingAndGivesAReference() {
    List<StewardTestData.Household> households = StewardTestData.existingHouseholds();
    List<User> customers = PortalTestData.createCustomers(households);
    AgentTestSessions sessions = new AgentTestSessions()
      .chat(1, customers[0].Id)
      .install();
    AgentActions.simulatedFailure = new DmlException('Simulated failure');

    OpenDisputeAction.Output output = OpenDisputeAction.run(
      new List<OpenDisputeAction.Input>{
        input(
          sessions.id(1),
          statementOf(households[0].account.Id).Id,
          PAYMENT_NOT_POSTED
        )
      }
    )[0];

    Assert.areEqual(StewardOutcome.FAILED, output.outcome, 'Failed');
    Assert.isNotNull(output.reference, 'A number to quote');
    Assert.isNull(output.caseNumber, 'No case');
  }

  private static Billing_Statement__c statementOf(Id accountId) {
    return [
      SELECT Id
      FROM Billing_Statement__c
      WHERE Account__c = :accountId
      WITH SYSTEM_MODE
      LIMIT 1
    ];
  }

  private static OpenDisputeAction.Input input(
    Id sessionId,
    String statementId,
    String reason
  ) {
    OpenDisputeAction.Input input = new OpenDisputeAction.Input();
    input.sessionId = sessionId;
    input.statementId = statementId;
    input.reason = reason;
    return input;
  }
}
