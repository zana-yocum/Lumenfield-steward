/**
 * ST-02, ST-12, S-08. The scoping tests for Steward's one read outside user mode. Proves a
 * household gets only its own commitments, as exactly five fields; a user who can't see the
 * household gets nothing; and a user who can see it gets its commitments without any access to
 * opportunities or commitments, which is the reason the service exists. Includes the
 * 200-household bulk test (NFR-02).
 */
@IsTest
private class CommitmentReadServiceTest {
  @TestSetup
  static void createData() {
    List<StewardTestData.Household> households = StewardTestData.createHouseholds(
      3,
      StewardTestData.ACCOUNT_CURRENT
    );
    List<Opportunity> deals = new List<Opportunity>{
      StewardTestData.deal(households[0]),
      StewardTestData.deal(households[1])
    };
    insert deals;
    insert new List<Commitment__c>{
      StewardTestData.commitment(
        deals[0],
        'Payment Coverage',
        240.00,
        2,
        'Lumenfield covers the first two monthly payments.',
        'Recorded'
      ),
      StewardTestData.commitment(
        deals[0],
        'Promotional Credit',
        100.00,
        null,
        'A $100 welcome credit on the first statement.',
        'Applied'
      ),
      StewardTestData.commitment(
        deals[1],
        'Referral Bonus',
        50.00,
        null,
        'Referral bonus for the neighbor who referred them.',
        'Recorded'
      )
    };
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
  static void aHouseholdGetsOnlyItsOwnCommitments() {
    List<Account> accounts = households();

    Test.startTest();
    CommitmentReadService.HouseholdCommitments mine = CommitmentReadService.forHousehold(
      accounts[0].Id
    );
    Test.stopTest();

    Assert.areEqual(StewardOutcome.COMPLETED, mine.outcome, 'Completed');
    Assert.areEqual(2, mine.commitments.size(), 'Its two commitments');
    CommitmentReadService.CommitmentView coverage = mine.commitments[0];
    Assert.areEqual(
      'Payment Coverage',
      coverage.commitmentType,
      'Type, in type order'
    );
    Assert.areEqual(240.00, coverage.value, 'Value');
    Assert.areEqual(2, coverage.monthsCovered, 'Months covered');
    Assert.areEqual(
      'Lumenfield covers the first two monthly payments.',
      coverage.terms,
      'Terms'
    );
    Assert.areEqual('Recorded', coverage.status, 'Status');
    Assert.isNull(mine.commitments[1].monthsCovered, 'Blank months stay blank');
    for (CommitmentReadService.CommitmentView view : mine.commitments) {
      Assert.areNotEqual(
        'Referral Bonus',
        view.commitmentType,
        'Never another household\'s commitment'
      );
    }
  }

  @IsTest
  static void onlyTheFiveCustomerFieldsLeaveTheService() {
    CommitmentReadService.CommitmentView view = CommitmentReadService.forHousehold(
        households()[0].Id
      )
      .commitments[0];

    Map<String, Object> fields = (Map<String, Object>) JSON.deserializeUntyped(
      JSON.serialize(view)
    );

    Assert.areEqual(
      new Set<String>{
        'commitmentType',
        'value',
        'monthsCovered',
        'terms',
        'status'
      },
      fields.keySet(),
      'No opportunity, amount, stage, sales rep or recorded-by'
    );
  }

  @IsTest
  static void aHouseholdWithNoneSaysNoneRecorded() {
    Test.startTest();
    CommitmentReadService.HouseholdCommitments none = CommitmentReadService.forHousehold(
      households()[2].Id
    );
    Test.stopTest();

    Assert.areEqual(StewardOutcome.COMPLETED, none.outcome, 'Completed');
    Assert.areEqual(
      CommitmentReadService.NONE_RECORDED,
      none.reasonCode,
      'Says none were recorded'
    );
    Assert.isTrue(none.commitments.isEmpty(), 'Empty list');
  }

  @IsTest
  static void aUserWhoCannotSeeTheHouseholdGetsNothing() {
    Id householdId = households()[0].Id;
    User outsider = StewardTestData.createUserWithoutAccess();

    CommitmentReadService.HouseholdCommitments result;
    Test.startTest();
    System.runAs(outsider) {
      result = CommitmentReadService.forHousehold(householdId);
    }
    Test.stopTest();

    Assert.areEqual(
      StewardOutcome.NOT_FOUND,
      result.reasonCode,
      'Knowing the account ID is not enough'
    );
    Assert.isTrue(
      result.commitments.isEmpty(),
      'Nothing is read for a household out of reach'
    );
  }

  @IsTest
  static void aUserWhoCanSeeTheHouseholdGetsItsCommitmentsWithoutOpportunityAccess() {
    List<Account> accounts = households();
    User customerStandIn = StewardTestData.createUserWithoutAccess();
    StewardTestData.shareRead(accounts[0].Id, customerStandIn.Id);

    Map<Id, CommitmentReadService.HouseholdCommitments> results;
    Boolean directReadBlocked = false;
    Test.startTest();
    System.runAs(customerStandIn) {
      results = CommitmentReadService.forHouseholds(
        new Set<Id>{ accounts[0].Id, accounts[1].Id }
      );
      try {
        List<Commitment__c> direct = [
          SELECT Id
          FROM Commitment__c
          WITH USER_MODE
          LIMIT 1
        ];
        directReadBlocked = direct.isEmpty();
      } catch (Exception e) {
        directReadBlocked = true;
      }
    }
    Test.stopTest();

    Assert.isTrue(
      directReadBlocked,
      'The user has no access to commitments of its own'
    );
    Assert.areEqual(
      2,
      results.get(accounts[0].Id).commitments.size(),
      'Its own household\'s commitments, through the service (S-08)'
    );
    Assert.areEqual(
      StewardOutcome.NOT_FOUND,
      results.get(accounts[1].Id).reasonCode,
      'Another household stays out of reach in the same call'
    );
    Assert.isTrue(
      results.get(accounts[1].Id).commitments.isEmpty(),
      'Nothing from the other household'
    );
  }

  @IsTest
  static void missingIdsAreHandled() {
    Assert.areEqual(
      StewardOutcome.INVALID_REQUEST,
      CommitmentReadService.forHousehold(null).reasonCode,
      'No account, no commitments'
    );
    Assert.isTrue(
      CommitmentReadService.forHouseholds(null).isEmpty(),
      'A null set gives nothing'
    );
  }

  @IsTest
  static void reads200HouseholdsWithTwoQueries() {
    List<StewardTestData.Household> many = StewardTestData.createHouseholds(
      200,
      StewardTestData.ACCOUNT_CURRENT
    );
    List<Opportunity> deals = new List<Opportunity>();
    Set<Id> ids = new Set<Id>();
    for (StewardTestData.Household household : many) {
      deals.add(StewardTestData.deal(household));
      ids.add(household.account.Id);
    }
    insert deals;
    List<Commitment__c> commitments = new List<Commitment__c>();
    for (Opportunity deal : deals) {
      commitments.add(
        StewardTestData.commitment(
          deal,
          'Delayed Billing Start',
          0,
          1,
          'Billing starts one month after activation.',
          'Recorded'
        )
      );
    }
    insert commitments;

    Test.startTest();
    Map<Id, CommitmentReadService.HouseholdCommitments> results = CommitmentReadService.forHouseholds(
      ids
    );
    Integer queries = Limits.getQueries();
    Test.stopTest();

    Assert.areEqual(200, results.size(), 'One result each');
    Assert.isTrue(queries <= 2, 'Two queries at most, used ' + queries);
    for (CommitmentReadService.HouseholdCommitments result : results.values()) {
      Assert.areEqual(1, result.commitments.size(), 'Its own commitment only');
    }
  }
}
