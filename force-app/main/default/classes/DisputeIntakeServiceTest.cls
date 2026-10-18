/**
 * ST-06, ST-12, GR-02. Proves a dispute opened by Steward is handled exactly like one a rep opens:
 * Accord stamps the SLA entitlement, flags the statement, and its assignment rule routes the case
 * to Dispute Specialists. Also proves duplicates point to the open case, another household's
 * statement is not found, card numbers never reach the case, and the caller's own access applies
 * to every field but the account. Includes the 200-dispute bulk test (NFR-02).
 */
@IsTest
private class DisputeIntakeServiceTest {
  private static final String PAYMENT_NOT_POSTED = 'Payment Not Posted';

  @TestSetup
  static void createData() {
    List<StewardTestData.Household> households = StewardTestData.createHouseholds(
      2,
      StewardTestData.ACCOUNT_DELINQUENT
    );
    insert new List<Billing_Statement__c>{
      StewardTestData.statement(
        households[0],
        StewardTestData.monthStart(2),
        120.00,
        StewardTestData.STATEMENT_PAST_DUE
      ),
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

  private static List<Account> households() {
    return [
      SELECT Id, Primary_Contact__c
      FROM Account
      WHERE Name LIKE 'Steward Test Household%'
      ORDER BY Name
    ];
  }

  private static List<Billing_Statement__c> statementsOf(Id accountId) {
    return [
      SELECT Id, Dispute_Open__c, Status__c
      FROM Billing_Statement__c
      WHERE Account__c = :accountId
      ORDER BY Due_Date__c
    ];
  }

  private static DisputeIntakeService.DisputeResult openOne(
    Id accountId,
    Id statementId,
    String reason
  ) {
    return DisputeIntakeService.openDispute(
      new DisputeIntakeService.Request(accountId, statementId, reason)
    );
  }

  @IsTest
  static void opensADisputeAndAccordTakesOver() {
    Account household = households()[0];
    Billing_Statement__c statement = statementsOf(household.Id)[0];
    DisputeIntakeService.Request request = new DisputeIntakeService.Request(
      household.Id,
      statement.Id,
      PAYMENT_NOT_POSTED
    );
    request.description = 'I paid on the 3rd by bank transfer.';

    Test.startTest();
    DisputeIntakeService.DisputeResult result = DisputeIntakeService.openDispute(
      request
    );
    Test.stopTest();

    Assert.areEqual(StewardOutcome.COMPLETED, result.outcome, 'Completed');
    Assert.isTrue(
      String.isNotBlank(result.caseNumber),
      'The customer gets a case number'
    );
    Case dispute = [
      SELECT
        AccountId,
        ContactId,
        RecordType.DeveloperName,
        Disputed_Statement__c,
        Dispute_Reason__c,
        Origin,
        EntitlementId,
        OwnerId,
        Description
      FROM Case
      WHERE Id = :result.caseId
    ];
    Assert.areEqual(household.Id, dispute.AccountId, 'On the household');
    Assert.areEqual(
      household.Primary_Contact__c,
      dispute.ContactId,
      'From the primary contact'
    );
    Assert.areEqual(
      'Billing_Dispute',
      dispute.RecordType.DeveloperName,
      'A Billing Dispute'
    );
    Assert.areEqual(
      statement.Id,
      dispute.Disputed_Statement__c,
      'On the statement'
    );
    Assert.areEqual(
      PAYMENT_NOT_POSTED,
      dispute.Dispute_Reason__c,
      'With the reason'
    );
    Assert.areEqual('Web', dispute.Origin, 'From the web');
    Assert.areEqual(
      'I paid on the 3rd by bank transfer.',
      dispute.Description,
      'In the customer\'s words'
    );
    Assert.areEqual(
      [SELECT Id FROM Entitlement WHERE AccountId = :household.Id].Id,
      dispute.EntitlementId,
      'Accord stamped the SLA entitlement'
    );
    Assert.areEqual(
      [
        SELECT Id
        FROM Group
        WHERE Type = 'Queue' AND DeveloperName = 'Dispute_Specialists'
      ]
      .Id,
      dispute.OwnerId,
      'Accord\'s assignment rule routed it to Dispute Specialists'
    );
    Billing_Statement__c flagged = statementsOf(household.Id)[0];
    Assert.isTrue(flagged.Dispute_Open__c, 'Accord flagged the statement');
    Assert.areEqual('In Dispute', flagged.Status__c, 'Marked In Dispute');
  }

  @IsTest
  static void givesTheEvidenceListRequiredItemsFirst() {
    Account household = households()[0];

    Test.startTest();
    DisputeIntakeService.DisputeResult result = openOne(
      household.Id,
      statementsOf(household.Id)[0].Id,
      PAYMENT_NOT_POSTED
    );
    Test.stopTest();

    Assert.areEqual(2, result.evidence.size(), 'Two items for this reason');
    Assert.isTrue(result.evidence[0].required, 'Required first');
    Assert.areEqual(
      'Payment confirmation with number, date, and amount',
      result.evidence[0].item,
      'The required item'
    );
    Assert.isFalse(result.evidence[1].required, 'Optional after');
    Assert.areEqual(
      'Bank record showing the funds left the account',
      result.evidence[1].item,
      'The optional item'
    );
  }

  @IsTest
  static void aSecondDisputeOnTheSameStatementPointsToTheFirst() {
    Account household = households()[0];
    Billing_Statement__c statement = statementsOf(household.Id)[0];
    DisputeIntakeService.DisputeResult first = openOne(
      household.Id,
      statement.Id,
      PAYMENT_NOT_POSTED
    );

    Test.startTest();
    DisputeIntakeService.DisputeResult second = openOne(
      household.Id,
      statement.Id,
      'Duplicate or Unauthorized Draft'
    );
    Test.stopTest();

    Assert.areEqual(
      DisputeIntakeService.EXISTING_DISPUTE,
      second.reasonCode,
      'Already disputed'
    );
    Assert.areEqual(
      first.caseNumber,
      second.caseNumber,
      'Points to the open case'
    );
    Assert.areEqual(
      1,
      [SELECT COUNT() FROM Case WHERE Disputed_Statement__c = :statement.Id],
      'No duplicate case'
    );
  }

  @IsTest
  static void onlyOneDisputePerStatementInABatch() {
    Account household = households()[0];
    Id statementId = statementsOf(household.Id)[0].Id;

    Test.startTest();
    List<DisputeIntakeService.DisputeResult> results = DisputeIntakeService.openDisputes(
      new List<DisputeIntakeService.Request>{
        new DisputeIntakeService.Request(
          household.Id,
          statementId,
          PAYMENT_NOT_POSTED
        ),
        new DisputeIntakeService.Request(
          household.Id,
          statementId,
          PAYMENT_NOT_POSTED
        )
      }
    );
    Test.stopTest();

    Assert.areEqual(
      StewardOutcome.COMPLETED,
      results[0].outcome,
      'The first opens'
    );
    Assert.areEqual(
      DisputeIntakeService.EXISTING_DISPUTE,
      results[1].reasonCode,
      'The second is a duplicate'
    );
    Assert.areEqual(
      1,
      [SELECT COUNT() FROM Case WHERE Disputed_Statement__c = :statementId],
      'One case'
    );
  }

  @IsTest
  static void anotherHouseholdsStatementIsNotFound() {
    List<Account> accounts = households();
    Billing_Statement__c someoneElses = statementsOf(accounts[1].Id)[0];

    Test.startTest();
    DisputeIntakeService.DisputeResult result = openOne(
      accounts[0].Id,
      someoneElses.Id,
      PAYMENT_NOT_POSTED
    );
    Test.stopTest();

    Assert.areEqual(
      StewardOutcome.NOT_FOUND,
      result.reasonCode,
      'Not found, not refused'
    );
    Assert.isNull(result.caseNumber, 'No case');
    Assert.areEqual(0, [SELECT COUNT() FROM Case], 'Nothing created');
    Assert.isFalse(
      statementsOf(accounts[1].Id)[0].Dispute_Open__c,
      'The other household\'s statement is untouched'
    );
  }

  @IsTest
  static void declinesWhatIsNotAStatementDispute() {
    Account household = households()[0];
    Id statementId = statementsOf(household.Id)[1].Id;

    Test.startTest();
    List<DisputeIntakeService.DisputeResult> results = DisputeIntakeService.openDisputes(
      new List<DisputeIntakeService.Request>{
        new DisputeIntakeService.Request(
          household.Id,
          statementId,
          'Just credit my account'
        ),
        new DisputeIntakeService.Request(household.Id, statementId, null),
        new DisputeIntakeService.Request(
          household.Id,
          null,
          PAYMENT_NOT_POSTED
        ),
        new DisputeIntakeService.Request(null, statementId, PAYMENT_NOT_POSTED),
        null
      }
    );
    Test.stopTest();

    Assert.areEqual(
      DisputeIntakeService.INVALID_REASON,
      results[0].reasonCode,
      'Not one of the eight reasons'
    );
    Assert.areEqual(
      DisputeIntakeService.INVALID_REASON,
      results[1].reasonCode,
      'No reason'
    );
    Assert.areEqual(
      DisputeIntakeService.STATEMENT_REQUIRED,
      results[2].reasonCode,
      'A dispute has to name a statement'
    );
    Assert.areEqual(
      StewardOutcome.INVALID_REQUEST,
      results[3].reasonCode,
      'No account'
    );
    Assert.areEqual(
      StewardOutcome.INVALID_REQUEST,
      results[4].reasonCode,
      'No request'
    );
    Assert.areEqual(0, [SELECT COUNT() FROM Case], 'Nothing created');
    Assert.isTrue(
      DisputeIntakeService.openDisputes(null).isEmpty(),
      'A null list gives nothing'
    );
  }

  @IsTest
  static void aHouseholdOutOfReachIsNotFound() {
    Account household = households()[0];
    Id statementId = statementsOf(household.Id)[0].Id;
    User outsider = StewardTestData.createUserWithoutAccess();

    DisputeIntakeService.DisputeResult result;
    Test.startTest();
    System.runAs(outsider) {
      result = openOne(household.Id, statementId, PAYMENT_NOT_POSTED);
    }
    Test.stopTest();

    Assert.areEqual(
      StewardOutcome.NOT_FOUND,
      result.reasonCode,
      'Not found, not refused'
    );
    Assert.areEqual(0, [SELECT COUNT() FROM Case], 'Nothing created');
  }

  @IsTest
  static void cardNumbersNeverReachTheCase() {
    Account household = households()[0];
    DisputeIntakeService.Request request = new DisputeIntakeService.Request(
      household.Id,
      statementsOf(household.Id)[0].Id,
      'Duplicate or Unauthorized Draft'
    );
    request.description = 'My card 4111 1111 1111 1111 was charged twice.';

    Test.startTest();
    DisputeIntakeService.DisputeResult result = DisputeIntakeService.openDispute(
      request
    );
    Test.stopTest();

    String description = [
      SELECT Description
      FROM Case
      WHERE Id = :result.caseId
    ]
    .Description;
    Assert.isFalse(description.contains('4111'), 'No card digits');
    Assert.areEqual(
      'My card ' +
        SensitiveText.CARD_NUMBER_PLACEHOLDER +
        ' was charged twice.',
      description,
      'The rest of the words are kept'
    );
  }

  @IsTest
  static void appliesTheCallersAccessToEverythingButTheAccount() {
    Account household = households()[0];
    List<Case> disputes = new List<Case>{
      new Case(
        AccountId = household.Id,
        Subject = 'Billing dispute',
        Dispute_Reason__c = PAYMENT_NOT_POSTED
      )
    };
    User outsider = StewardTestData.createUserWithoutAccess();

    String asAdmin;
    String asOutsider;
    Test.startTest();
    asAdmin = DisputeIntakeService.blockedFields(disputes);
    System.runAs(outsider) {
      asOutsider = DisputeIntakeService.blockedFields(disputes);
    }
    Test.stopTest();

    Assert.isNull(
      asAdmin,
      'Nothing blocked: the read-only account field is the one exception (S-14)'
    );
    Assert.areEqual(
      'Case',
      asOutsider,
      'A user who can\'t create cases is stopped'
    );
  }

  @IsTest
  static void opens200DisputesInOneCall() {
    List<StewardTestData.Household> many = StewardTestData.createHouseholds(
      200,
      StewardTestData.ACCOUNT_DELINQUENT
    );
    List<Billing_Statement__c> statements = new List<Billing_Statement__c>();
    for (StewardTestData.Household household : many) {
      statements.add(
        StewardTestData.statement(
          household,
          StewardTestData.monthStart(1),
          120.00,
          StewardTestData.STATEMENT_PAST_DUE
        )
      );
    }
    insert statements;
    List<DisputeIntakeService.Request> requests = new List<DisputeIntakeService.Request>();
    Set<Id> statementIds = new Set<Id>();
    for (Billing_Statement__c statement : statements) {
      requests.add(
        new DisputeIntakeService.Request(
          statement.Account__c,
          statement.Id,
          PAYMENT_NOT_POSTED
        )
      );
      statementIds.add(statement.Id);
    }

    Test.startTest();
    List<DisputeIntakeService.DisputeResult> results = DisputeIntakeService.openDisputes(
      requests
    );
    Test.stopTest();

    for (DisputeIntakeService.DisputeResult result : results) {
      Assert.areEqual(
        StewardOutcome.COMPLETED,
        result.outcome,
        'Each opened: ' + result.reasonCode + ' ' + result.failureDetail
      );
    }
    Assert.areEqual(
      200,
      [SELECT COUNT() FROM Case WHERE Disputed_Statement__c IN :statementIds],
      'Two hundred cases'
    );
    Assert.areEqual(
      200,
      [
        SELECT COUNT()
        FROM Billing_Statement__c
        WHERE Id IN :statementIds AND Dispute_Open__c = TRUE
      ],
      'Accord flagged every statement'
    );
  }
}
