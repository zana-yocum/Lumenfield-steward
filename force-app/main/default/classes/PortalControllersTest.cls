/**
 * ST-01, ST-02, ST-06, ST-12, S-14, NFR-07. Proves the portal's three controllers as a real
 * customer user: each page gets the logged-in household's own records and nothing of another
 * household's, even when the page sends another household's ID. Opening a dispute hands it to
 * Accord, and evidence files attach only to the household's own dispute. A customer who can't set
 * one of the dispute's fields is refused, naming the field (S-14). Every failure comes back as a
 * reference to quote, with the error in the action log.
 *
 * Household A: a past-due $120 statement with a $50 payment, an open one, and a paid one with an
 * open dispute; a commitment from signing. Household B: two statements, one disputed, and a
 * commitment of its own.
 */
@IsTest
private class PortalControllersTest {
  private static final String PAYMENT_NOT_POSTED = 'Payment Not Posted';
  private static final String PROMISED_CREDIT = 'Promised Credit Not Applied';
  private static final String TERMS_A = 'Rep agreed Lumenfield would cover the first 3 monthly payments.';
  private static final String TERMS_B = 'Rep promised a $150 promotional credit applied to the first statement.';
  private static final String REFERENCE_PATTERN = 'AAL-\\d+';

  @TestSetup
  static void createData() {
    PortalTestData.giveRunningUserARole();
    List<StewardTestData.Household> households = StewardTestData.createHouseholds(
      2,
      StewardTestData.ACCOUNT_DELINQUENT
    );
    StewardTestData.Household householdA = households[0];
    StewardTestData.Household householdB = households[1];
    List<Billing_Statement__c> statements = new List<Billing_Statement__c>{
      StewardTestData.statement(
        householdA,
        StewardTestData.monthStart(2),
        120,
        StewardTestData.STATEMENT_PAST_DUE
      ),
      StewardTestData.statement(
        householdA,
        Date.today().addDays(14),
        120,
        StewardTestData.STATEMENT_OPEN
      ),
      StewardTestData.statement(
        householdA,
        StewardTestData.monthStart(3),
        120,
        StewardTestData.STATEMENT_PAID
      ),
      StewardTestData.statement(
        householdB,
        StewardTestData.monthStart(2),
        120,
        StewardTestData.STATEMENT_PAST_DUE
      ),
      StewardTestData.statement(
        householdB,
        StewardTestData.monthStart(1),
        120,
        StewardTestData.STATEMENT_PAST_DUE
      )
    };
    insert statements;
    insert new List<Payment__c>{
      StewardTestData.payment(
        statements[0],
        50,
        StewardTestData.monthStart(2).addDays(-1)
      ),
      StewardTestData.payment(
        statements[2],
        120,
        StewardTestData.monthStart(3).addDays(-2)
      )
    };
    StewardTestData.insertDispute(
      householdA,
      statements[2],
      PAYMENT_NOT_POSTED
    );
    StewardTestData.insertDispute(
      householdB,
      statements[3],
      PAYMENT_NOT_POSTED
    );

    List<Opportunity> deals = new List<Opportunity>{
      StewardTestData.deal(householdA),
      StewardTestData.deal(householdB)
    };
    insert deals;
    insert new List<Commitment__c>{
      StewardTestData.commitment(
        deals[0],
        'Payment Coverage',
        360,
        3,
        TERMS_A,
        'Recorded'
      ),
      StewardTestData.commitment(
        deals[1],
        'Promotional Credit',
        150,
        null,
        TERMS_B,
        'Recorded'
      )
    };
  }

  @IsTest
  static void myAccountShowsTheHouseholdsOwnBalancesAndStatements() {
    Account householdA = household(0);
    User customer = customerOf(householdA, null);
    AccountSnapshotService.Snapshot result;
    Test.startTest();
    System.runAs(customer) {
      result = PortalAccountController.getMyAccount();
    }
    Test.stopTest();
    Account expected = [
      SELECT Current_Balance__c, Past_Due_Balance__c
      FROM Account
      WHERE Id = :householdA.Id
      WITH SYSTEM_MODE
    ];
    Assert.areEqual(StewardOutcome.COMPLETED, result.outcome, 'Found');
    Assert.areEqual(householdA.Id, result.accountId, 'Their own household');
    Assert.areEqual(
      expected.Current_Balance__c,
      result.currentBalance,
      'The balance a rep sees, to the cent'
    );
    Assert.areEqual(
      expected.Past_Due_Balance__c,
      result.pastDueBalance,
      'The past-due amount a rep sees'
    );
    Assert.areEqual(
      3,
      result.statements.size(),
      'Only household A\'s three statements'
    );
  }

  @IsTest
  static void aStatementFromAnotherHouseholdIsNotFound() {
    Account householdA = household(0);
    Id ownStatement = statementOf(
      householdA,
      StewardTestData.STATEMENT_PAST_DUE
    );
    Id otherStatement = statementOf(
      household(1),
      StewardTestData.STATEMENT_PAST_DUE
    );
    User customer = customerOf(householdA, null);
    PortalAccountController.StatementResult own;
    PortalAccountController.StatementResult other;
    Test.startTest();
    System.runAs(customer) {
      own = PortalAccountController.getStatement(ownStatement);
      other = PortalAccountController.getStatement(otherStatement);
    }
    Test.stopTest();
    Assert.areEqual(
      StewardOutcome.COMPLETED,
      own.outcome,
      'Their own statement'
    );
    Assert.areEqual(
      ownStatement,
      own.statement.statementId,
      'The one asked for'
    );
    Assert.areEqual(1, own.statement.payments.size(), 'With its payment');
    Assert.areEqual(50, own.statement.payments[0].amount, 'Of $50.00');
    Assert.areEqual(
      StewardOutcome.NOT_FOUND,
      other.reasonCode,
      'Another household\'s ID finds nothing (ST-12)'
    );
    Assert.isNull(other.statement, 'And nothing about it comes back');
  }

  @IsTest
  static void commitmentsShowOnlyTheHouseholdsOwn() {
    Account householdA = household(0);
    User customer = customerOf(householdA, null);
    CommitmentReadService.HouseholdCommitments result;
    Test.startTest();
    System.runAs(customer) {
      result = PortalCommitmentsController.getMyCommitments();
    }
    Test.stopTest();
    Assert.areEqual(StewardOutcome.COMPLETED, result.outcome, 'Found');
    Assert.areEqual(
      1,
      result.commitments.size(),
      'Only household A\'s commitment'
    );
    CommitmentReadService.CommitmentView seen = result.commitments[0];
    Assert.areEqual('Payment Coverage', seen.commitmentType, 'Its type');
    Assert.areEqual(360, seen.value, 'Its value');
    Assert.areEqual(3, seen.monthsCovered, 'Its months');
    Assert.areEqual(TERMS_A, seen.terms, 'Its terms, as recorded');
    Assert.areEqual('Recorded', seen.status, 'Its status');
  }

  @IsTest
  static void disputesListAndDetailStayInTheHousehold() {
    Account householdA = household(0);
    Id disputeA = disputeOf(householdA);
    Id disputeB = disputeOf(household(1));
    User customer = customerOf(householdA, null);
    DisputeStatusService.HouseholdDisputes mine;
    DisputeStatusService.DisputeDetail own;
    DisputeStatusService.DisputeDetail other;
    Test.startTest();
    System.runAs(customer) {
      mine = PortalDisputesController.getMyDisputes();
      own = PortalDisputesController.getDispute(disputeA);
      other = PortalDisputesController.getDispute(disputeB);
    }
    Test.stopTest();
    Assert.areEqual(1, mine.disputes.size(), 'Only household A\'s dispute');
    Assert.areEqual(disputeA, mine.disputes[0].caseId, 'Which is this one');
    Assert.areEqual(StewardOutcome.COMPLETED, own.outcome, 'Its detail');
    Assert.isFalse(own.evidence.isEmpty(), 'With what to send');
    Assert.areEqual(
      StewardOutcome.NOT_FOUND,
      other.reasonCode,
      'B\'s dispute ID finds nothing'
    );
  }

  // ST-06. The dispute page's upload area saves each file the way this test does: a new file
  // version published to the case, as the customer, with their sharing and permissions.
  @IsTest
  static void evidenceAttachesToTheHouseholdsOwnDisputeOnly() {
    Account householdA = household(0);
    Id disputeA = disputeOf(householdA);
    Id disputeB = disputeOf(household(1));
    User customer = customerOf(householdA, null);
    List<Database.SaveResult> saved;
    Test.startTest();
    System.runAs(customer) {
      saved = Database.insert(
        new List<ContentVersion>{
          evidenceFile('bank-record.pdf', disputeA),
          evidenceFile('someone-elses.pdf', disputeB)
        },
        false,
        AccessLevel.USER_MODE
      );
    }
    Test.stopTest();
    Assert.isTrue(
      saved[0].isSuccess(),
      'A customer can attach evidence to their own dispute: ' +
      saved[0].getErrors()
    );
    Assert.isFalse(
      saved[1].isSuccess(),
      'But not to another household\'s dispute (ST-12)'
    );
    List<ContentDocumentLink> links = [
      SELECT LinkedEntityId
      FROM ContentDocumentLink
      WHERE LinkedEntityId IN (:disputeA, :disputeB)
      WITH SYSTEM_MODE
    ];
    Assert.areEqual(1, links.size(), 'One file arrived');
    Assert.areEqual(
      disputeA,
      links[0].LinkedEntityId,
      'On household A\'s dispute, where Accord\'s specialists work it'
    );
  }

  @IsTest
  static void theFormListsTheReasonsAndTheHouseholdsStatements() {
    Account householdA = household(0);
    Id disputedStatement = disputedStatementOf(householdA);
    User customer = customerOf(householdA, null);
    PortalDisputesController.DisputeForm form;
    Test.startTest();
    System.runAs(customer) {
      form = PortalDisputesController.getDisputeForm();
    }
    Test.stopTest();
    Assert.areEqual(StewardOutcome.COMPLETED, form.outcome, 'Found');
    Assert.areEqual(8, form.reasons.size(), 'Accord\'s eight dispute reasons');
    for (DisputeEvidenceCatalog.ReasonOption reason : form.reasons) {
      Assert.isFalse(reason.evidence.isEmpty(), 'Each with its evidence list');
    }
    Assert.areEqual(
      3,
      form.statements.size(),
      'Household A\'s three statements'
    );
    for (PortalDisputesController.StatementOption option : form.statements) {
      if (option.statementId == disputedStatement) {
        Assert.isTrue(
          String.isNotBlank(option.disputeCaseNumber),
          'A statement already in dispute names its case'
        );
      }
    }
  }

  @IsTest
  static void openingADisputeHandsItToAccord() {
    Account householdA = household(0);
    Id statementId = statementOf(
      householdA,
      StewardTestData.STATEMENT_PAST_DUE
    );
    User customer = customerOf(householdA, null);
    DisputeIntakeService.DisputeResult result;
    Test.startTest();
    System.runAs(customer) {
      result = PortalDisputesController.openDispute(
        statementId,
        PAYMENT_NOT_POSTED,
        'I paid on the 3rd with my card 4111 1111 1111 1111.'
      );
    }
    Test.stopTest();
    Assert.areEqual(
      StewardOutcome.COMPLETED,
      result.outcome,
      'Opened' + loggedReason(result)
    );
    Assert.isTrue(
      String.isNotBlank(result.caseNumber),
      'The customer can read their new case back, through the sharing set (S-16)'
    );
    Assert.isTrue(result.evidence[0].required, 'Required evidence first');
    Case saved = [
      SELECT
        Customer_Household__c,
        Description,
        Owner.Name,
        Disputed_Statement__r.Status__c
      FROM Case
      WHERE Id = :result.caseId
      WITH SYSTEM_MODE
    ];
    Assert.areEqual(
      householdA.Id,
      saved.Customer_Household__c,
      'Stamped with the household'
    );
    Assert.isFalse(
      saved.Description.contains('4111'),
      'The card number never reaches the case'
    );
    Assert.areEqual(
      'Dispute Specialists',
      saved.Owner.Name,
      'Accord\'s assignment rule routed it'
    );
    Assert.areEqual(
      'In Dispute',
      saved.Disputed_Statement__r.Status__c,
      'Accord\'s flow flagged the statement'
    );
  }

  @IsTest
  static void anotherHouseholdsStatementCannotBeDisputed() {
    Account householdA = household(0);
    Account householdB = household(1);
    Id otherStatement = statementOf(
      householdB,
      StewardTestData.STATEMENT_PAST_DUE
    );
    User customer = customerOf(householdA, null);
    DisputeIntakeService.DisputeResult result;
    Test.startTest();
    System.runAs(customer) {
      result = PortalDisputesController.openDispute(
        otherStatement,
        PAYMENT_NOT_POSTED,
        null
      );
    }
    Test.stopTest();
    Assert.areEqual(
      StewardOutcome.NOT_FOUND,
      result.reasonCode,
      'Not found' + loggedReason(result)
    );
    Assert.areEqual(
      0,
      [
        SELECT COUNT()
        FROM Case
        WHERE Disputed_Statement__c = :otherStatement
        WITH SYSTEM_MODE
      ],
      'Nothing was opened on B\'s statement'
    );
  }

  @IsTest
  static void aSecondDisputePointsToTheFirst() {
    Account householdA = household(0);
    Id statementId = disputedStatementOf(householdA);
    Id existing = disputeOf(householdA);
    User customer = customerOf(householdA, null);
    DisputeIntakeService.DisputeResult result;
    Test.startTest();
    System.runAs(customer) {
      result = PortalDisputesController.openDispute(
        statementId,
        PROMISED_CREDIT,
        null
      );
    }
    Test.stopTest();
    Assert.areEqual(
      DisputeIntakeService.EXISTING_DISPUTE,
      result.reasonCode,
      'Already in dispute' + loggedReason(result)
    );
    Assert.areEqual(existing, result.caseId, 'Points to the open dispute');
  }

  @IsTest
  static void aCustomerWhoCannotSetTheReasonIsRefusedByName() {
    Account householdB = household(1);
    Id statementId = statementOf(
      householdB,
      StewardTestData.STATEMENT_PAST_DUE
    );
    Id withoutReason = customerAccessWithoutReason();
    User customer = customerOf(householdB, withoutReason);
    DisputeIntakeService.DisputeResult result;
    Test.startTest();
    System.runAs(customer) {
      result = PortalDisputesController.openDispute(
        statementId,
        PAYMENT_NOT_POSTED,
        null
      );
    }
    Test.stopTest();
    Assert.areEqual(StewardOutcome.FAILED, result.outcome, 'Refused');
    Assert.areEqual(
      DisputeIntakeService.ACCESS_DENIED,
      result.reasonCode,
      'For lack of access (S-14)' + loggedReason(result)
    );
    Assert.isNull(result.failureDetail, 'No detail leaves the server (NFR-07)');
    Assert.isTrue(
      Pattern.matches(REFERENCE_PATTERN, result.reference),
      'A reference to quote instead: ' + result.reference
    );
    Agent_Action_Log__c logged = [
      SELECT Details__c, Outcome__c
      FROM Agent_Action_Log__c
      WHERE Name = :result.reference
      WITH SYSTEM_MODE
    ];
    Assert.isTrue(
      logged.Details__c.contains('Dispute_Reason__c'),
      'The log names the field the customer can\'t set: ' + logged.Details__c
    );
    Assert.areEqual(
      0,
      [
        SELECT COUNT()
        FROM Case
        WHERE Disputed_Statement__c = :statementId
        WITH SYSTEM_MODE
      ],
      'Nothing was saved'
    );
  }

  @IsTest
  static void aUserWithNoHouseholdGetsNothing() {
    Test.startTest();
    AccountSnapshotService.Snapshot account = PortalAccountController.getMyAccount();
    PortalAccountController.StatementResult statement = PortalAccountController.getStatement(
      statementOf(household(0), StewardTestData.STATEMENT_PAST_DUE)
    );
    CommitmentReadService.HouseholdCommitments commitments = PortalCommitmentsController.getMyCommitments();
    DisputeStatusService.HouseholdDisputes disputes = PortalDisputesController.getMyDisputes();
    PortalDisputesController.DisputeForm form = PortalDisputesController.getDisputeForm();
    Test.stopTest();
    // The running user is internal: no contact, so no household.
    for (
      StewardOutcome.Result result : new List<StewardOutcome.Result>{
        account,
        statement,
        commitments,
        disputes,
        form
      }
    ) {
      Assert.areEqual(
        StewardOutcome.INVALID_REQUEST,
        result.reasonCode,
        'No household, nothing to show'
      );
    }
    Assert.isTrue(form.reasons.isEmpty(), 'Not even the form');
  }

  @IsTest
  static void failuresComeBackAsAReferenceToQuote() {
    Id statementId = statementOf(
      household(0),
      StewardTestData.STATEMENT_PAST_DUE
    );
    Id disputeId = disputeOf(household(0));
    PortalHousehold.simulatedFailure = new DmlException('Simulated failure');
    Test.startTest();
    List<StewardOutcome.Result> results = new List<StewardOutcome.Result>{
      PortalAccountController.getMyAccount(),
      PortalAccountController.getStatement(statementId),
      PortalCommitmentsController.getMyCommitments(),
      PortalDisputesController.getMyDisputes(),
      PortalDisputesController.getDisputeForm(),
      PortalDisputesController.getDispute(disputeId),
      PortalDisputesController.openDispute(
        statementId,
        PAYMENT_NOT_POSTED,
        null
      )
    };
    Test.stopTest();
    Set<String> references = new Set<String>();
    for (StewardOutcome.Result result : results) {
      Assert.areEqual(StewardOutcome.FAILED, result.outcome, 'Failed');
      Assert.areEqual(
        PortalFailure.UNEXPECTED_ERROR,
        result.reasonCode,
        'Unexpectedly'
      );
      Assert.isTrue(
        Pattern.matches(REFERENCE_PATTERN, result.reference),
        'With a reference to quote: ' + result.reference
      );
      references.add(result.reference);
    }
    Assert.areEqual(
      7,
      references.size(),
      'A separate reference for each failure'
    );
    for (Agent_Action_Log__c logged : [
      SELECT Details__c, Outcome__c, Action__c
      FROM Agent_Action_Log__c
      WHERE Name IN :references
      WITH SYSTEM_MODE
    ]) {
      Assert.areEqual('Failed', logged.Outcome__c, 'Logged as a failure');
      Assert.isTrue(
        logged.Details__c.startsWith('System.DmlException: Simulated failure'),
        'The error is in the log, not in front of the customer'
      );
      Assert.isTrue(
        logged.Action__c.startsWith('Portal'),
        'Named by where it happened'
      );
    }
  }

  private static Account household(Integer index) {
    return [
      SELECT Id
      FROM Account
      WHERE Name LIKE 'Steward Test Household%'
      ORDER BY Name
      LIMIT 1
      OFFSET :index
    ];
  }

  // A statement by status. Opening a dispute changes its statement's status to In Dispute, so
  // each household has exactly one statement in each status the tests ask for.
  private static Id statementOf(Account household, String status) {
    return [
      SELECT Id
      FROM Billing_Statement__c
      WHERE Account__c = :household.Id AND Status__c = :status
      ORDER BY Due_Date__c DESC
      LIMIT 1
    ]
    .Id;
  }

  private static Id disputedStatementOf(Account household) {
    return [
      SELECT Disputed_Statement__c
      FROM Case
      WHERE
        AccountId = :household.Id
        AND RecordType.DeveloperName = :StewardTestData.DISPUTE_RECORD_TYPE
      LIMIT 1
    ]
    .Disputed_Statement__c;
  }

  private static Id disputeOf(Account household) {
    return [
      SELECT Id
      FROM Case
      WHERE
        AccountId = :household.Id
        AND RecordType.DeveloperName = :StewardTestData.DISPUTE_RECORD_TYPE
      LIMIT 1
    ]
    .Id;
  }

  // A file uploaded in the portal belongs to the portal's network, as the upload area's are.
  private static ContentVersion evidenceFile(String fileName, Id disputeId) {
    return new ContentVersion(
      Title = fileName,
      PathOnClient = fileName,
      VersionData = Blob.valueOf('Fictional evidence for a test.'),
      FirstPublishLocationId = disputeId,
      NetworkId = [
        SELECT Id
        FROM Network
        WHERE Name = 'Lumenfield Customer Portal'
        LIMIT 1
      ]
      .Id
    );
  }

  // What the action log recorded for a failed result, so a failing assertion says why.
  private static String loggedReason(StewardOutcome.Result result) {
    if (result?.reference == null) {
      return '';
    }
    List<Agent_Action_Log__c> logged = [
      SELECT Details__c
      FROM Agent_Action_Log__c
      WHERE Name = :result.reference
      WITH SYSTEM_MODE
    ];
    return logged.isEmpty() ? '' : ' (logged: ' + logged[0].Details__c + ')';
  }

  private static User customerOf(Account household, Id permissionSetId) {
    StewardTestData.Household wrapper = new StewardTestData.Household();
    wrapper.account = household;
    wrapper.primaryContact = [
      SELECT Id
      FROM Contact
      WHERE AccountId = :household.Id
      LIMIT 1
    ];
    List<StewardTestData.Household> one = new List<StewardTestData.Household>{
      wrapper
    };
    return permissionSetId == null
      ? PortalTestData.createCustomers(one)[0]
      : PortalTestData.createCustomers(one, permissionSetId)[0];
  }

  // A copy of PS_Steward_Customer without create access on the dispute's reason: everything a
  // customer needs to reach the dispute form, except one field the dispute sets.
  private static Id customerAccessWithoutReason() {
    Id original = [
      SELECT Id
      FROM PermissionSet
      WHERE Name = :PortalTestData.CUSTOMER_PERMISSION_SET
    ]
    .Id;
    PermissionSet copy = new PermissionSet(
      Name = 'Steward_Test_No_Reason',
      Label = 'Steward Test No Reason'
    );
    List<ObjectPermissions> objectAccess = new List<ObjectPermissions>();
    List<FieldPermissions> fieldAccess = new List<FieldPermissions>();
    System.runAs(new User(Id = UserInfo.getUserId())) {
      insert copy;
      for (ObjectPermissions access : [
        SELECT SobjectType, PermissionsRead, PermissionsCreate
        FROM ObjectPermissions
        WHERE ParentId = :original
      ]) {
        objectAccess.add(
          new ObjectPermissions(
            ParentId = copy.Id,
            SobjectType = access.SobjectType,
            PermissionsRead = access.PermissionsRead,
            PermissionsCreate = access.PermissionsCreate
          )
        );
      }
      for (FieldPermissions access : [
        SELECT SobjectType, Field, PermissionsRead, PermissionsEdit
        FROM FieldPermissions
        WHERE ParentId = :original
      ]) {
        fieldAccess.add(
          new FieldPermissions(
            ParentId = copy.Id,
            SobjectType = access.SobjectType,
            Field = access.Field,
            PermissionsRead = access.PermissionsRead,
            PermissionsEdit = access.Field == 'Case.Dispute_Reason__c'
              ? false
              : access.PermissionsEdit
          )
        );
      }
      insert objectAccess;
      insert fieldAccess;
    }
    return copy.Id;
  }
}
