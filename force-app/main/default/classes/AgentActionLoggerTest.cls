/**
 * ST-11, S-09, GR-06. Proves every outcome is logged with its label, card numbers never reach the
 * log, a log is written even when the caller can't see the account, and a bad entry is reported
 * instead of breaking the action. Includes the 200-record bulk test (NFR-02).
 *
 * Read-backs use WITH SYSTEM_MODE. They check what was stored, and no profile or permission set
 * has field access to the log yet: supervisors get it in Phase 6. A plain query in a test checks
 * field-level security, so it can't see the new fields (found in the first Phase 3 validation).
 */
@IsTest
private class AgentActionLoggerTest {
  private static final String ACTION = 'CreatePaymentArrangementAction';

  @TestSetup
  static void createData() {
    StewardTestData.createHousehold();
  }

  private static AgentActionLogger.Entry entry(
    Id accountId,
    String outcome,
    String reasonCode
  ) {
    StewardOutcome.Result result = new StewardOutcome.Result();
    result.setOutcome(outcome, reasonCode);
    return new AgentActionLogger.Entry(accountId, ACTION, result);
  }

  @IsTest
  static void anEntryWithoutAResultIsLoggedAsAFailure() {
    AgentActionLogger.Entry noResult = new AgentActionLogger.Entry(
      householdId(),
      ACTION,
      null
    );

    Test.startTest();
    Database.SaveResult save = AgentActionLogger.log(noResult);
    Test.stopTest();

    Assert.areEqual(
      'Failed',
      [
        SELECT Outcome__c
        FROM Agent_Action_Log__c
        WHERE Id = :save.getId()
        WITH SYSTEM_MODE
      ]
      .Outcome__c,
      'Never lost: recorded as a failure'
    );
  }

  private static Id householdId() {
    return [
      SELECT Id
      FROM Account
      WHERE Name LIKE 'Steward Test Household%'
      LIMIT 1
    ]
    .Id;
  }

  @IsTest
  static void logsEveryOutcomeWithItsLabel() {
    Id accountId = householdId();
    List<AgentActionLogger.Entry> entries = new List<AgentActionLogger.Entry>{
      entry(accountId, StewardOutcome.COMPLETED, null),
      entry(accountId, StewardOutcome.DECLINED_POLICY, 'DATE_OUTSIDE_WINDOW'),
      entry(accountId, StewardOutcome.HANDOFF, 'ACCOUNT_STATUS'),
      entry(accountId, StewardOutcome.FAILED, 'SAVE_FAILED')
    };
    entries[1].conversationId = '0Mwaj0000000001AAA';

    Test.startTest();
    List<Database.SaveResult> saves = AgentActionLogger.log(entries);
    Test.stopTest();

    for (Database.SaveResult save : saves) {
      Assert.isTrue(save.isSuccess(), 'Each entry saves: ' + save.getErrors());
    }
    Map<String, Agent_Action_Log__c> byOutcome = new Map<String, Agent_Action_Log__c>();
    for (Agent_Action_Log__c row : [
      SELECT
        Name,
        Account__c,
        Action__c,
        Outcome__c,
        Reason_Code__c,
        Conversation_Id__c
      FROM Agent_Action_Log__c
      WITH SYSTEM_MODE
    ]) {
      byOutcome.put(row.Outcome__c, row);
      Assert.areEqual(accountId, row.Account__c, 'The household is recorded');
      Assert.areEqual(ACTION, row.Action__c, 'The action is recorded');
      Assert.isTrue(row.Name.startsWith('AAL-'), 'Numbered for reference');
    }
    Assert.areEqual(
      new Set<String>{
        'Completed',
        'Declined by Policy',
        'Handed Off',
        'Failed'
      },
      byOutcome.keySet(),
      'All four outcomes are logged with their labels'
    );
    Assert.areEqual(
      'DATE_OUTSIDE_WINDOW',
      byOutcome.get('Declined by Policy').Reason_Code__c,
      'The policy reason is recorded'
    );
    Assert.areEqual(
      '0Mwaj0000000001AAA',
      byOutcome.get('Declined by Policy').Conversation_Id__c,
      'The conversation is recorded'
    );
  }

  @IsTest
  static void removesCardNumbersAndTrimsLongText() {
    AgentActionLogger.Entry longEntry = entry(
      householdId(),
      StewardOutcome.DECLINED_POLICY,
      'CARD_IN_CHAT'
    );
    longEntry.action = ACTION.repeat(5);
    longEntry.details =
      'Customer typed 4111 1111 1111 1111 and ' + 'x'.repeat(3000);

    Test.startTest();
    Database.SaveResult save = AgentActionLogger.log(longEntry);
    Test.stopTest();

    Assert.isTrue(save.isSuccess(), 'The entry saves: ' + save.getErrors());
    Agent_Action_Log__c row = [
      SELECT Action__c, Details__c
      FROM Agent_Action_Log__c
      WHERE Id = :save.getId()
      WITH SYSTEM_MODE
    ];
    Assert.isFalse(
      row.Details__c.contains('4111'),
      'No card digits reach the log'
    );
    Assert.isTrue(
      row.Details__c.startsWith(
        'Customer typed ' + SensitiveText.CARD_NUMBER_PLACEHOLDER
      ),
      'The number is replaced, not just dropped'
    );
    Assert.areEqual(2000, row.Details__c.length(), 'Details are cut to fit');
    Assert.areEqual(80, row.Action__c.length(), 'The action is cut to fit');
  }

  @IsTest
  static void unknownOutcomeIsRecordedAsAFailure() {
    AgentActionLogger.Entry badCode = entry(householdId(), 'NOT_A_CODE', null);
    badCode.details = 'Something was asked';

    Test.startTest();
    Database.SaveResult save = AgentActionLogger.log(badCode);
    Test.stopTest();

    Agent_Action_Log__c row = [
      SELECT Outcome__c, Details__c
      FROM Agent_Action_Log__c
      WHERE Id = :save.getId()
      WITH SYSTEM_MODE
    ];
    Assert.areEqual('Failed', row.Outcome__c, 'Kept, as a failure');
    Assert.isTrue(
      row.Details__c.startsWith('Unknown outcome code: NOT_A_CODE'),
      'The bad code is recorded: ' + row.Details__c
    );
  }

  @IsTest
  static void logsEvenWhenTheCallerCannotSeeTheAccount() {
    Id accountId = householdId();
    User outsider = StewardTestData.createUserWithoutAccess();

    Database.SaveResult save;
    Test.startTest();
    System.runAs(outsider) {
      save = AgentActionLogger.log(
        entry(
          accountId,
          StewardOutcome.DECLINED_POLICY,
          StewardOutcome.NOT_FOUND
        )
      );
    }
    Test.stopTest();

    Assert.isTrue(
      save.isSuccess(),
      'A user with no access to the account or the log still leaves a record: ' +
      save.getErrors()
    );
    Assert.areEqual(
      1,
      [
        SELECT COUNT()
        FROM Agent_Action_Log__c
        WHERE Account__c = :accountId
        WITH SYSTEM_MODE
      ],
      'The declined request is on record'
    );
  }

  @IsTest
  static void badEntryIsReportedNotThrown() {
    Contact notAnAccount = [SELECT Id FROM Contact LIMIT 1];

    Test.startTest();
    Database.SaveResult save = AgentActionLogger.log(
      entry(notAnAccount.Id, StewardOutcome.COMPLETED, null)
    );
    Test.stopTest();

    Assert.isFalse(save.isSuccess(), 'A contact ID in the account field fails');
    Assert.areEqual(
      0,
      [SELECT COUNT() FROM Agent_Action_Log__c WITH SYSTEM_MODE],
      'Nothing is saved, and nothing was thrown'
    );
  }

  @IsTest
  static void nothingToLogReturnsNothing() {
    Assert.isTrue(
      AgentActionLogger.log((List<AgentActionLogger.Entry>) null).isEmpty(),
      'A null list logs nothing'
    );
    Assert.isNull(
      AgentActionLogger.log((AgentActionLogger.Entry) null),
      'A null entry logs nothing'
    );
  }

  @IsTest
  static void logs200EntriesInOneSave() {
    Id accountId = householdId();
    List<AgentActionLogger.Entry> entries = new List<AgentActionLogger.Entry>();
    for (Integer i = 0; i < 200; i++) {
      entries.add(entry(accountId, StewardOutcome.COMPLETED, null));
    }

    Test.startTest();
    List<Database.SaveResult> saves = AgentActionLogger.log(entries);
    Integer dmlStatements = Limits.getDmlStatements();
    Test.stopTest();

    Assert.areEqual(200, saves.size(), 'One result per entry');
    Assert.areEqual(1, dmlStatements, 'All 200 in a single save');
    Assert.areEqual(
      200,
      [SELECT COUNT() FROM Agent_Action_Log__c WITH SYSTEM_MODE],
      'All 200 saved'
    );
  }
}
