/**
 * ST-06, ST-12, S-16. Proves a customer sees their own household's billing disputes, newest
 * first, with the evidence list for one dispute, and never another household's dispute or one of
 * Accord's default reviews, even on their own account. Proves the flow stamps the household on
 * disputes only, and clears it when a case stops being a dispute. Includes the 200-household bulk
 * test (NFR-02).
 *
 * Household A has two open disputes and a default review. Household B has one dispute.
 */
@IsTest
private class DisputeStatusServiceTest {
  private static final String PAYMENT_NOT_POSTED = 'Payment Not Posted';
  private static final String DUPLICATE_DRAFT = 'Duplicate or Unauthorized Draft';

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
        StewardTestData.monthStart(3),
        120,
        StewardTestData.STATEMENT_PAST_DUE
      ),
      StewardTestData.statement(
        householdA,
        StewardTestData.monthStart(2),
        120,
        StewardTestData.STATEMENT_PAST_DUE
      ),
      StewardTestData.statement(
        householdB,
        StewardTestData.monthStart(2),
        120,
        StewardTestData.STATEMENT_PAST_DUE
      )
    };
    insert statements;
    StewardTestData.insertDispute(
      householdA,
      statements[0],
      PAYMENT_NOT_POSTED
    );
    StewardTestData.insertDispute(householdA, statements[1], DUPLICATE_DRAFT);
    StewardTestData.insertDispute(
      householdB,
      statements[2],
      PAYMENT_NOT_POSTED
    );
    PortalTestData.insertDefaultReview(householdA);
  }

  @IsTest
  static void aCustomerSeesTheirDisputesNewestFirst() {
    Account householdA = household(0);
    User customer = customerOf(householdA);
    DisputeStatusService.HouseholdDisputes result;
    Test.startTest();
    System.runAs(customer) {
      result = DisputeStatusService.forHousehold(householdA.Id);
    }
    Test.stopTest();
    Assert.areEqual(StewardOutcome.COMPLETED, result.outcome, 'Found');
    Assert.areEqual(
      2,
      result.disputes.size(),
      'Both of the household\'s disputes'
    );
    DisputeStatusService.DisputeView newest = result.disputes[0];
    Assert.areEqual(
      DUPLICATE_DRAFT,
      newest.reason,
      'The newer dispute comes first'
    );
    Assert.areEqual(
      PAYMENT_NOT_POSTED,
      result.disputes[1].reason,
      'Then the older one'
    );
    Assert.isFalse(newest.isClosed, 'It is open');
    Assert.isTrue(String.isNotBlank(newest.caseNumber), 'With its case number');
    Assert.isTrue(String.isNotBlank(newest.status), 'And its status');
    Assert.isNotNull(newest.statementId, 'And the statement it is about');
    Assert.isTrue(
      String.isNotBlank(newest.statementNumber),
      'By statement number'
    );
    Assert.areEqual(Date.today(), newest.openedDate, 'Opened today');
  }

  @IsTest
  static void aCustomerNeverSeesDefaultReviewsOrOtherHouseholds() {
    Account householdA = household(0);
    Account householdB = household(1);
    User customer = customerOf(householdA);
    List<Case> visible;
    DisputeStatusService.HouseholdDisputes other;
    Test.startTest();
    System.runAs(customer) {
      visible = [SELECT Id, RecordType.DeveloperName FROM Case WITH USER_MODE];
      other = DisputeStatusService.forHousehold(householdB.Id);
    }
    Test.stopTest();
    Assert.areEqual(
      2,
      visible.size(),
      'Only the household\'s two disputes: not its default review, not B\'s dispute (S-16)'
    );
    for (Case seen : visible) {
      Assert.areEqual(
        StewardTestData.DISPUTE_RECORD_TYPE,
        seen.RecordType.DeveloperName,
        'Every case the customer can see is a billing dispute'
      );
    }
    Assert.areEqual(
      StewardOutcome.NOT_FOUND,
      other.reasonCode,
      'B is out of reach'
    );
    Assert.isTrue(other.disputes.isEmpty(), 'Nothing about B comes back');
  }

  @IsTest
  static void oneDisputeComesWithItsEvidenceList() {
    Account householdA = household(0);
    Id disputeA = caseOf(householdA, PAYMENT_NOT_POSTED);
    Id disputeB = caseOf(household(1), PAYMENT_NOT_POSTED);
    Id reviewA = [
      SELECT Id
      FROM Case
      WHERE
        AccountId = :householdA.Id
        AND RecordType.DeveloperName = :PortalTestData.DEFAULT_REVIEW_RECORD_TYPE
    ]
    .Id;
    User customer = customerOf(householdA);
    DisputeStatusService.DisputeDetail own;
    DisputeStatusService.DisputeDetail others;
    DisputeStatusService.DisputeDetail review;
    Test.startTest();
    System.runAs(customer) {
      own = DisputeStatusService.getDispute(householdA.Id, disputeA);
      others = DisputeStatusService.getDispute(householdA.Id, disputeB);
      review = DisputeStatusService.getDispute(householdA.Id, reviewA);
    }
    Test.stopTest();
    Assert.areEqual(StewardOutcome.COMPLETED, own.outcome, 'Their own dispute');
    Assert.areEqual(disputeA, own.dispute.caseId, 'The one asked for');
    Assert.areEqual(PAYMENT_NOT_POSTED, own.dispute.reason, 'With its reason');
    Assert.areEqual(
      2,
      own.evidence.size(),
      'Payment Not Posted lists two items'
    );
    Assert.isTrue(own.evidence[0].required, 'The required item first');
    Assert.isFalse(own.evidence[1].required, 'Then the optional one');
    Assert.areEqual(
      StewardOutcome.NOT_FOUND,
      others.reasonCode,
      'B\'s dispute is not found'
    );
    Assert.isNull(others.dispute, 'And nothing about it comes back');
    Assert.areEqual(
      StewardOutcome.NOT_FOUND,
      review.reasonCode,
      'A default review is not a dispute, even on their own account'
    );
  }

  @IsTest
  static void missingIdsAreHandled() {
    Account householdA = household(0);
    Test.startTest();
    Map<Id, DisputeStatusService.HouseholdDisputes> none = DisputeStatusService.forHouseholds(
      null
    );
    DisputeStatusService.HouseholdDisputes noHousehold = DisputeStatusService.forHousehold(
      null
    );
    DisputeStatusService.DisputeDetail noCase = DisputeStatusService.getDispute(
      householdA.Id,
      null
    );
    DisputeStatusService.DisputeDetail noAccount = DisputeStatusService.getDispute(
      null,
      caseOf(householdA, PAYMENT_NOT_POSTED)
    );
    Test.stopTest();
    Assert.isTrue(none.isEmpty(), 'No households asked for, none returned');
    Assert.areEqual(
      StewardOutcome.INVALID_REQUEST,
      noHousehold.reasonCode,
      'No household'
    );
    Assert.areEqual(
      StewardOutcome.INVALID_REQUEST,
      noCase.reasonCode,
      'No case'
    );
    Assert.areEqual(
      StewardOutcome.INVALID_REQUEST,
      noAccount.reasonCode,
      'No household for the case'
    );
  }

  // S-16. Any save puts a dispute's household right, even an attempt to clear it. That's how the
  // disputes from before the flow were backfilled. A default review stays without one.
  @IsTest
  static void anySaveRepairsADisputesHousehold() {
    Account householdA = household(0);
    Id disputeId = caseOf(householdA, PAYMENT_NOT_POSTED);
    Id reviewId = [
      SELECT Id
      FROM Case
      WHERE
        AccountId = :householdA.Id
        AND RecordType.DeveloperName = :PortalTestData.DEFAULT_REVIEW_RECORD_TYPE
      WITH SYSTEM_MODE
    ]
    .Id;
    Test.startTest();
    // System mode: no profile can set the field, and the test is about what the flow does.
    Database.update(
      new List<Case>{
        new Case(Id = disputeId, Customer_Household__c = null),
        new Case(Id = reviewId)
      },
      AccessLevel.SYSTEM_MODE
    );
    Test.stopTest();
    Map<Id, Case> saved = new Map<Id, Case>(
      [
        SELECT Customer_Household__c
        FROM Case
        WHERE Id IN (:disputeId, :reviewId)
        WITH SYSTEM_MODE
      ]
    );
    Assert.areEqual(
      householdA.Id,
      saved.get(disputeId).Customer_Household__c,
      'The dispute keeps its household'
    );
    Assert.isNull(
      saved.get(reviewId).Customer_Household__c,
      'The default review stays without one'
    );
  }

  @IsTest
  static void theFlowStampsTheHouseholdOnDisputesOnly() {
    Account householdA = household(0);
    Id disputeId = caseOf(householdA, PAYMENT_NOT_POSTED);
    Test.startTest();
    Case dispute = [
      SELECT Id, Customer_Household__c
      FROM Case
      WHERE Id = :disputeId
      WITH SYSTEM_MODE
    ];
    Case review = [
      SELECT Id, Customer_Household__c
      FROM Case
      WHERE
        AccountId = :householdA.Id
        AND RecordType.DeveloperName = :PortalTestData.DEFAULT_REVIEW_RECORD_TYPE
      WITH SYSTEM_MODE
    ];
    // A dispute that becomes something else stops being visible to the customer.
    update new Case(
      Id = disputeId,
      RecordTypeId = Schema.SObjectType.Case.getRecordTypeInfosByDeveloperName()
        .get(PortalTestData.DEFAULT_REVIEW_RECORD_TYPE)
        .getRecordTypeId()
    );
    Test.stopTest();
    Case changed = [
      SELECT Customer_Household__c
      FROM Case
      WHERE Id = :disputeId
      WITH SYSTEM_MODE
    ];
    Assert.areEqual(
      householdA.Id,
      dispute.Customer_Household__c,
      'A billing dispute carries its household'
    );
    Assert.isNull(review.Customer_Household__c, 'A default review never does');
    Assert.isNull(
      changed.Customer_Household__c,
      'Cleared when a case stops being a dispute'
    );
  }

  @IsTest
  static void reads200HouseholdsWithTwoQueries() {
    List<StewardTestData.Household> many = StewardTestData.createHouseholds(
      200,
      StewardTestData.ACCOUNT_DELINQUENT
    );
    List<Billing_Statement__c> statements = new List<Billing_Statement__c>();
    for (StewardTestData.Household household : many) {
      statements.add(
        StewardTestData.statement(
          household,
          StewardTestData.monthStart(2),
          120,
          StewardTestData.STATEMENT_PAST_DUE
        )
      );
    }
    insert statements;
    Id recordTypeId = Schema.SObjectType.Case.getRecordTypeInfosByDeveloperName()
      .get(StewardTestData.DISPUTE_RECORD_TYPE)
      .getRecordTypeId();
    List<Case> disputes = new List<Case>();
    Set<Id> accountIds = new Set<Id>();
    for (Integer i = 0; i < many.size(); i++) {
      accountIds.add(many[i].account.Id);
      disputes.add(
        new Case(
          RecordTypeId = recordTypeId,
          AccountId = many[i].account.Id,
          ContactId = many[i].primaryContact.Id,
          Disputed_Statement__c = statements[i].Id,
          Dispute_Reason__c = PAYMENT_NOT_POSTED,
          Origin = 'Phone',
          Subject = 'Billing dispute'
        )
      );
    }
    insert disputes;

    Test.startTest();
    Integer before = Limits.getQueries();
    Map<Id, DisputeStatusService.HouseholdDisputes> results = DisputeStatusService.forHouseholds(
      accountIds
    );
    Integer used = Limits.getQueries() - before;
    Test.stopTest();
    Assert.areEqual(
      2,
      used,
      'One household check and one case query, however many households'
    );
    Assert.areEqual(200, results.size(), 'A result for every household');
    for (DisputeStatusService.HouseholdDisputes result : results.values()) {
      Assert.areEqual(
        1,
        result.disputes.size(),
        'Each household\'s one dispute'
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

  private static Id caseOf(Account household, String reason) {
    return [
      SELECT Id
      FROM Case
      WHERE
        AccountId = :household.Id
        AND Dispute_Reason__c = :reason
        AND RecordType.DeveloperName = :StewardTestData.DISPUTE_RECORD_TYPE
      LIMIT 1
    ]
    .Id;
  }

  private static User customerOf(Account household) {
    StewardTestData.Household wrapper = new StewardTestData.Household();
    wrapper.account = household;
    wrapper.primaryContact = [
      SELECT Id
      FROM Contact
      WHERE AccountId = :household.Id
      LIMIT 1
    ];
    return PortalTestData.createCustomers(
      new List<StewardTestData.Household>{ wrapper }
    )[0];
  }
}
