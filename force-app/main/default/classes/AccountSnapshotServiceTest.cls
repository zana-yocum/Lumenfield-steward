/**
 * ST-01, ST-12, GR-04. Proves the snapshot carries Accord's balances to the cent, lists statements
 * newest first with their payments (date and amount only), marks disputed statements, shows the
 * open promise, and returns NOT_FOUND for a household the caller can't see. Includes the
 * 200-household bulk test (NFR-02).
 *
 * The known-answer household: four $120 statements. One paid in full, two past due (one with a
 * $50 payment), and one open and due in two weeks. Current balance $310, past due $190.
 */
@IsTest
private class AccountSnapshotServiceTest {
  private static final String ORGANIZATION_NAME = 'Steward Test Organization';

  @TestSetup
  static void createData() {
    List<StewardTestData.Household> households = StewardTestData.createHouseholds(
      3,
      StewardTestData.ACCOUNT_DELINQUENT
    );
    StewardTestData.Household known = households[0];
    StewardTestData.Household disputed = households[2];

    StewardTestData.addKnownAnswerHistory(known);
    Billing_Statement__c disputedStatement = StewardTestData.statement(
      disputed,
      StewardTestData.monthStart(2),
      120,
      StewardTestData.STATEMENT_PAST_DUE
    );
    insert disputedStatement;
    StewardTestData.insertDispute(
      disputed,
      disputedStatement,
      'Payment Not Posted'
    );
    // Inserted here rather than in the test method: an account insert followed by a user insert in
    // one test made that test take two minutes in the first Phase 3 validation.
    insert new Account(
      Name = ORGANIZATION_NAME,
      RecordTypeId = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName()
        .get('Organization')
        .getRecordTypeId()
    );
  }

  private static List<Account> households() {
    return [
      SELECT Id
      FROM Account
      WHERE Name LIKE 'Steward Test Household%'
      ORDER BY Name
    ];
  }

  @IsTest
  static void carriesAccordsBalancesToTheCent() {
    Id knownId = households()[0].Id;

    Test.startTest();
    AccountSnapshotService.Snapshot snapshot = AccountSnapshotService.getSnapshot(
      knownId
    );
    Test.stopTest();

    Assert.areEqual(StewardOutcome.COMPLETED, snapshot.outcome, 'Completed');
    Assert.areEqual(310.00, snapshot.currentBalance, 'Current balance');
    Assert.areEqual(190.00, snapshot.pastDueBalance, 'Past-due balance');
    Assert.areEqual(
      StewardTestData.monthStart(3),
      snapshot.oldestPastDueDate,
      'Oldest past-due date is the oldest unpaid statement'
    );
    Assert.areEqual(
      Date.today().addDays(14),
      snapshot.nextDueDate,
      'Next due date is the open statement'
    );
    Assert.areEqual(120.00, snapshot.nextDueAmount, 'Next amount due');
    Account rollups = [
      SELECT Current_Balance__c, Past_Due_Balance__c
      FROM Account
      WHERE Id = :knownId
    ];
    Assert.areEqual(
      rollups.Current_Balance__c,
      snapshot.currentBalance,
      'Same number a rep sees'
    );
    Assert.areEqual(
      rollups.Past_Due_Balance__c,
      snapshot.pastDueBalance,
      'Same past-due number a rep sees'
    );
  }

  @IsTest
  static void listsStatementsNewestFirstWithTheirPayments() {
    Test.startTest();
    AccountSnapshotService.Snapshot snapshot = AccountSnapshotService.getSnapshot(
      households()[0].Id
    );
    Test.stopTest();

    Assert.areEqual(4, snapshot.statements.size(), 'Four statements');
    for (Integer i = 1; i < snapshot.statements.size(); i++) {
      Assert.isTrue(
        snapshot.statements[i - 1].statementDate >
        snapshot.statements[i].statementDate,
        'Newest first'
      );
    }
    AccountSnapshotService.StatementLine partlyPaid = snapshot.statements[1];
    Assert.areEqual(120.00, partlyPaid.amountDue, 'Amount due');
    Assert.areEqual(50.00, partlyPaid.amountPaid, 'Amount paid');
    Assert.areEqual(0.00, partlyPaid.creditsApplied, 'No credits');
    Assert.areEqual(70.00, partlyPaid.balance, 'Balance');
    Assert.areEqual(1, partlyPaid.payments.size(), 'Its payment');
    Assert.areEqual(50.00, partlyPaid.payments[0].amount, 'Payment amount');
    Assert.areEqual(
      StewardTestData.monthStart(2).addDays(-1),
      partlyPaid.payments[0].paymentDate,
      'Payment date'
    );
    Assert.areEqual(
      0.00,
      snapshot.statements[3].balance,
      'The oldest statement is paid off'
    );
  }

  @IsTest
  static void paymentsShowDateAndAmountOnly() {
    AccountSnapshotService.PaymentLine line = AccountSnapshotService.getSnapshot(
        households()[0].Id
      )
      .statements[3]
      .payments[0];

    Map<String, Object> fields = (Map<String, Object>) JSON.deserializeUntyped(
      JSON.serialize(line)
    );

    Assert.areEqual(
      new Set<String>{ 'paymentId', 'paymentNumber', 'paymentDate', 'amount' },
      fields.keySet(),
      'No payment method or processor reference leaves the service'
    );
  }

  @IsTest
  static void showsTheOpenPromise() {
    Test.startTest();
    AccountSnapshotService.Snapshot snapshot = AccountSnapshotService.getSnapshot(
      households()[0].Id
    );
    Test.stopTest();

    Integer graceDays = StewardTestData.policyNumber('Promise_Grace_Days')
      .intValue();
    Assert.isNotNull(snapshot.openPromise, 'The promise is shown');
    Assert.areEqual(190.00, snapshot.openPromise.amount, 'Promise amount');
    Assert.areEqual('Active', snapshot.openPromise.status, 'Promise status');
    Assert.areEqual(
      Date.today().addDays(10 + graceDays),
      snapshot.openPromise.graceEnds,
      'Grace ends after Accord\'s grace days'
    );
  }

  @IsTest
  static void marksADisputedStatement() {
    Id disputedId = households()[2].Id;
    Case dispute = [
      SELECT CaseNumber
      FROM Case
      WHERE AccountId = :disputedId
      LIMIT 1
    ];

    Test.startTest();
    AccountSnapshotService.Snapshot snapshot = AccountSnapshotService.getSnapshot(
      disputedId
    );
    Test.stopTest();

    AccountSnapshotService.StatementLine line = snapshot.statements[0];
    Assert.isTrue(line.disputeOpen, 'Accord flagged the statement');
    Assert.areEqual('In Dispute', line.status, 'Marked In Dispute');
    Assert.areEqual(
      dispute.CaseNumber,
      line.disputeCaseNumber,
      'Links to the dispute'
    );
  }

  @IsTest
  static void householdWithNoStatementsHasNothingOwed() {
    Test.startTest();
    AccountSnapshotService.Snapshot snapshot = AccountSnapshotService.getSnapshot(
      households()[1].Id
    );
    Test.stopTest();

    Assert.areEqual(StewardOutcome.COMPLETED, snapshot.outcome, 'Completed');
    Assert.areEqual(0.00, snapshot.currentBalance, 'Nothing owed');
    Assert.areEqual(0.00, snapshot.pastDueBalance, 'Nothing past due');
    Assert.isTrue(snapshot.statements.isEmpty(), 'No statements');
    Assert.isNull(snapshot.nextDueDate, 'Nothing coming due');
    Assert.isNull(snapshot.openPromise, 'No promise');
  }

  @IsTest
  static void outOfReachHouseholdsAreNotFound() {
    Id knownId = households()[0].Id;
    Account organization = [
      SELECT Id
      FROM Account
      WHERE Name = :ORGANIZATION_NAME
      LIMIT 1
    ];
    User outsider = StewardTestData.createUserWithoutAccess();

    AccountSnapshotService.Snapshot asOutsider;
    Test.startTest();
    System.runAs(outsider) {
      asOutsider = AccountSnapshotService.getSnapshot(knownId);
    }
    AccountSnapshotService.Snapshot notAHousehold = AccountSnapshotService.getSnapshot(
      organization.Id
    );
    AccountSnapshotService.Snapshot noId = AccountSnapshotService.getSnapshot(
      null
    );
    Test.stopTest();

    Assert.areEqual(
      StewardOutcome.NOT_FOUND,
      asOutsider.reasonCode,
      'Another user\'s household is not found, not refused'
    );
    Assert.isNull(asOutsider.currentBalance, 'Nothing about it is returned');
    Assert.isTrue(asOutsider.statements.isEmpty(), 'No statements returned');
    Assert.areEqual(
      StewardOutcome.NOT_FOUND,
      notAHousehold.reasonCode,
      'An Organization account is not a household'
    );
    Assert.areEqual(
      StewardOutcome.INVALID_REQUEST,
      noId.reasonCode,
      'No account, no snapshot'
    );
    Assert.isTrue(
      AccountSnapshotService.getSnapshots(null).isEmpty(),
      'A null set gives nothing'
    );
  }

  @IsTest
  static void reads200HouseholdsWithTheSameSixQueries() {
    List<StewardTestData.Household> many = StewardTestData.createHouseholds(
      200,
      StewardTestData.ACCOUNT_DELINQUENT
    );
    List<Billing_Statement__c> statements = new List<Billing_Statement__c>();
    Set<Id> ids = new Set<Id>();
    for (StewardTestData.Household household : many) {
      statements.add(
        StewardTestData.statement(
          household,
          StewardTestData.monthStart(2),
          120,
          StewardTestData.STATEMENT_PAST_DUE
        )
      );
      ids.add(household.account.Id);
    }
    insert statements;

    Test.startTest();
    Map<Id, AccountSnapshotService.Snapshot> snapshots = AccountSnapshotService.getSnapshots(
      ids
    );
    Integer queries = Limits.getQueries();
    Test.stopTest();

    Assert.areEqual(200, snapshots.size(), 'One snapshot each');
    Assert.isTrue(queries <= 6, 'Six queries at most, used ' + queries);
    for (AccountSnapshotService.Snapshot snapshot : snapshots.values()) {
      Assert.areEqual(StewardOutcome.COMPLETED, snapshot.outcome, 'Completed');
      Assert.areEqual(120.00, snapshot.pastDueBalance, 'Past due for each');
      Assert.areEqual(1, snapshot.statements.size(), 'Its own statement only');
    }
  }
}
