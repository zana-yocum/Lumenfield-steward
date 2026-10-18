/**
 * ST-04, ST-12, GR-02, GR-03. Proves an arrangement inside policy saves as Active and Accord's
 * flow puts the account on hold; every way outside policy is declined or handed off with the
 * right reason and nothing saved; and if Accord's flow would send a promise for approval, the
 * service rolls it back. Policy values are read from Accord's records, never assumed. Includes
 * the 200-household bulk test (NFR-02).
 */
@IsTest
private class PaymentArrangementServiceTest {
  private static final Integer PAST_DUE_190 = 0;
  private static final Integer PAST_DUE_120 = 1;
  private static final Integer HAS_ACTIVE = 2;
  private static final Integer HAS_PENDING = 3;
  private static final Integer BROKEN_PROMISES = 4;
  private static final Integer NOTHING_DUE = 5;
  private static final Integer DEFAULT_REVIEW = 6;
  private static final Integer HARDSHIP_REVIEW = 7;
  private static final Integer CLOSED_ACCOUNT = 8;

  @TestSetup
  static void createData() {
    List<StewardTestData.Household> households = StewardTestData.createHouseholds(
      5,
      StewardTestData.ACCOUNT_DELINQUENT
    );
    households.addAll(
      StewardTestData.createHouseholds(1, StewardTestData.ACCOUNT_CURRENT)
    );
    households.addAll(StewardTestData.createHouseholds(1, 'Default Review'));
    households.addAll(StewardTestData.createHouseholds(1, 'Hardship Review'));
    households.addAll(StewardTestData.createHouseholds(1, 'Closed'));

    List<Billing_Statement__c> statements = new List<Billing_Statement__c>{
      StewardTestData.statement(
        households[PAST_DUE_190],
        StewardTestData.monthStart(2),
        120.00,
        StewardTestData.STATEMENT_PAST_DUE
      ),
      StewardTestData.statement(
        households[NOTHING_DUE],
        Date.today().addDays(14),
        120.00,
        StewardTestData.STATEMENT_OPEN
      )
    };
    for (
      Integer i : new List<Integer>{
        PAST_DUE_190,
        PAST_DUE_120,
        HAS_ACTIVE,
        HAS_PENDING,
        BROKEN_PROMISES,
        DEFAULT_REVIEW,
        HARDSHIP_REVIEW,
        CLOSED_ACCOUNT
      }
    ) {
      statements.add(
        StewardTestData.statement(
          households[i],
          StewardTestData.monthStart(1),
          120.00,
          StewardTestData.STATEMENT_PAST_DUE
        )
      );
    }
    insert statements;
    // $120 + ($120 - $50) = $190 past due.
    insert StewardTestData.payment(
      statements[2],
      50.00,
      StewardTestData.monthStart(1).addDays(-1)
    );

    // Inside policy, so Accord's flow keeps it Active.
    insert StewardTestData.promise(
      households[HAS_ACTIVE],
      Date.today().addDays(5),
      120.00,
      'Active'
    );
    // Saved directly as Pending Approval, the way an out-of-policy promise ends up.
    insert StewardTestData.promise(
      households[HAS_PENDING],
      Date.today().addDays(40),
      60.00,
      'Pending Approval'
    );

    Account broken = households[BROKEN_PROMISES].account;
    broken.Broken_Promises_90d__c = PolicySettings.getNumber(
      PolicySettings.SELF_SERVICE_BROKEN_PROMISE_LIMIT
    );
    update broken;
  }

  private static List<Account> households() {
    return [
      SELECT Id
      FROM Account
      WHERE Name LIKE 'Steward Test Household%'
      ORDER BY Name
    ];
  }

  private static Integer windowDays() {
    return PolicySettings.getWholeNumber(PolicySettings.PROMISE_WINDOW_DAYS);
  }

  private static PaymentArrangementService.ArrangementResult createOne(
    Id accountId,
    Date promiseDate,
    Decimal amount
  ) {
    return PaymentArrangementService.createArrangements(
      new List<PaymentArrangementService.Request>{
        new PaymentArrangementService.Request(accountId, promiseDate, amount)
      }
    )[0];
  }

  private static PaymentArrangementService.ArrangementResult checkOne(
    Id accountId,
    Date promiseDate,
    Decimal amount
  ) {
    return PaymentArrangementService.checkEligibility(
      new List<PaymentArrangementService.Request>{
        new PaymentArrangementService.Request(accountId, promiseDate, amount)
      }
    )[0];
  }

  private static Integer promiseCount(Id accountId) {
    return [
      SELECT COUNT()
      FROM Promise_to_Pay__c
      WHERE Account__c = :accountId
    ];
  }

  @IsTest
  static void createsAnActivePromiseAndAccordPutsTheAccountOnHold() {
    Id householdId = households()[PAST_DUE_190].Id;
    Date promiseDate = Date.today().addDays(10);

    Test.startTest();
    PaymentArrangementService.ArrangementResult result = createOne(
      householdId,
      promiseDate,
      190.00
    );
    Test.stopTest();

    Integer graceDays = StewardTestData.policyNumber('Promise_Grace_Days')
      .intValue();
    Assert.areEqual(StewardOutcome.COMPLETED, result.outcome, 'Completed');
    Assert.isNotNull(result.promiseId, 'The promise is saved');
    Assert.areEqual('Active', result.promiseStatus, 'Saved as Active');
    Assert.isTrue(
      result.promiseNumber.length() > 0,
      'Numbered for the customer'
    );
    Assert.areEqual(
      promiseDate.addDays(graceDays),
      result.holdUntil,
      'Grace ends after Accord\'s grace days'
    );
    Promise_to_Pay__c saved = [
      SELECT Status__c, Promise_Amount__c, Promise_Date__c
      FROM Promise_to_Pay__c
      WHERE Id = :result.promiseId
    ];
    Assert.areEqual(190.00, saved.Promise_Amount__c, 'Amount as confirmed');
    Assert.areEqual(promiseDate, saved.Promise_Date__c, 'Date as confirmed');
    Account household = [
      SELECT Collection_Hold_Until__c
      FROM Account
      WHERE Id = :householdId
    ];
    Assert.areEqual(
      result.holdUntil,
      household.Collection_Hold_Until__c,
      'Accord\'s flow ran on Steward\'s save and set the hold (GR-02)'
    );
  }

  @IsTest
  static void theLastDayOfTheWindowIsAllowed() {
    Date lastDay = Date.today().addDays(windowDays());

    Test.startTest();
    PaymentArrangementService.ArrangementResult result = checkOne(
      households()[PAST_DUE_190].Id,
      lastDay,
      190.00
    );
    Test.stopTest();

    Assert.areEqual(
      PaymentArrangementService.ELIGIBLE,
      result.reasonCode,
      'The window\'s last day is inside it'
    );
    Assert.areEqual(lastDay, result.latestAllowedDate, 'Latest date');
    Assert.areEqual(190.00, result.minimumAmount, 'Minimum is the past due');
    Assert.areEqual(190.00, result.pastDueBalance, 'Past due from Accord');
  }

  @IsTest
  static void aDateOutsideTheWindowIsDeclinedWithTheLatestDate() {
    Id householdId = households()[PAST_DUE_190].Id;

    Test.startTest();
    PaymentArrangementService.ArrangementResult result = createOne(
      householdId,
      Date.today().addDays(windowDays() + 1),
      190.00
    );
    Test.stopTest();

    Assert.areEqual(StewardOutcome.DECLINED_POLICY, result.outcome, 'Declined');
    Assert.areEqual(
      PaymentArrangementService.DATE_OUTSIDE_WINDOW,
      result.reasonCode,
      'Outside the window'
    );
    Assert.areEqual(
      Date.today().addDays(windowDays()),
      result.latestAllowedDate,
      'Tells the customer the latest date it can arrange'
    );
    Assert.areEqual(0, promiseCount(householdId), 'Nothing saved');
  }

  @IsTest
  static void aDateInThePastIsDeclined() {
    Test.startTest();
    PaymentArrangementService.ArrangementResult result = createOne(
      households()[PAST_DUE_190].Id,
      Date.today().addDays(-1),
      190.00
    );
    Test.stopTest();

    Assert.areEqual(
      PaymentArrangementService.DATE_IN_PAST,
      result.reasonCode,
      'Yesterday can\'t be promised'
    );
  }

  @IsTest
  static void lessThanThePastDueBalanceIsDeclined() {
    Id householdId = households()[PAST_DUE_190].Id;

    Test.startTest();
    PaymentArrangementService.ArrangementResult result = createOne(
      householdId,
      Date.today().addDays(10),
      189.99
    );
    Test.stopTest();

    Assert.areEqual(
      PaymentArrangementService.AMOUNT_BELOW_MINIMUM,
      result.reasonCode,
      'Short of the past-due balance'
    );
    Assert.areEqual(190.00, result.minimumAmount, 'Says what would cover it');
    Assert.areEqual(0, promiseCount(householdId), 'Nothing saved');
  }

  @IsTest
  static void anExistingPromiseIsReportedNotDuplicated() {
    List<Account> accounts = households();

    Test.startTest();
    List<PaymentArrangementService.ArrangementResult> results = PaymentArrangementService.createArrangements(
      new List<PaymentArrangementService.Request>{
        new PaymentArrangementService.Request(
          accounts[HAS_ACTIVE].Id,
          Date.today().addDays(10),
          120.00
        ),
        new PaymentArrangementService.Request(
          accounts[HAS_PENDING].Id,
          Date.today().addDays(10),
          120.00
        )
      }
    );
    Test.stopTest();

    Assert.areEqual(
      PaymentArrangementService.EXISTING_PROMISE,
      results[0].reasonCode,
      'An Active promise already exists'
    );
    Assert.areEqual(
      120.00,
      results[0].existingPromiseAmount,
      'Its amount is given'
    );
    Assert.areEqual(
      Date.today().addDays(5),
      results[0].existingPromiseDate,
      'Its date is given'
    );
    Assert.areEqual(
      PaymentArrangementService.EXISTING_PROMISE,
      results[1].reasonCode,
      'A promise awaiting approval counts too'
    );
    Assert.areEqual(
      'Pending Approval',
      results[1].existingPromiseStatus,
      'Its status is given'
    );
    Assert.areEqual(
      1,
      promiseCount(accounts[HAS_ACTIVE].Id),
      'No second promise'
    );
    Assert.areEqual(
      1,
      promiseCount(accounts[HAS_PENDING].Id),
      'No second promise'
    );
  }

  @IsTest
  static void reviewAndClosedAccountsGoToAPerson() {
    List<Account> accounts = households();
    List<PaymentArrangementService.Request> requests = new List<PaymentArrangementService.Request>();
    for (
      Integer i : new List<Integer>{
        DEFAULT_REVIEW,
        HARDSHIP_REVIEW,
        CLOSED_ACCOUNT
      }
    ) {
      requests.add(
        new PaymentArrangementService.Request(
          accounts[i].Id,
          Date.today().addDays(10),
          120.00
        )
      );
    }

    Test.startTest();
    List<PaymentArrangementService.ArrangementResult> results = PaymentArrangementService.createArrangements(
      requests
    );
    Test.stopTest();

    for (PaymentArrangementService.ArrangementResult result : results) {
      Assert.areEqual(StewardOutcome.HANDOFF, result.outcome, 'Handed off');
      Assert.areEqual(
        PaymentArrangementService.ACCOUNT_STATUS,
        result.reasonCode,
        'Because of the account status'
      );
      Assert.isNull(
        result.pastDueBalance,
        'No collections figures are revealed'
      );
    }
    Set<Id> reviewIds = new Set<Id>{
      accounts[DEFAULT_REVIEW].Id,
      accounts[HARDSHIP_REVIEW].Id,
      accounts[CLOSED_ACCOUNT].Id
    };
    Assert.areEqual(
      0,
      [SELECT COUNT() FROM Promise_to_Pay__c WHERE Account__c IN :reviewIds],
      'Nothing saved'
    );
  }

  @IsTest
  static void tooManyBrokenPromisesGoToAPerson() {
    Test.startTest();
    PaymentArrangementService.ArrangementResult result = createOne(
      households()[BROKEN_PROMISES].Id,
      Date.today().addDays(10),
      120.00
    );
    Test.stopTest();

    Assert.areEqual(StewardOutcome.HANDOFF, result.outcome, 'Handed off');
    Assert.areEqual(
      PaymentArrangementService.BROKEN_PROMISE_LIMIT,
      result.reasonCode,
      'Because of recent broken promises'
    );
    Assert.isNull(result.pastDueBalance, 'No figures are revealed');
  }

  @IsTest
  static void nothingPastDueMeansNothingToArrange() {
    Test.startTest();
    PaymentArrangementService.ArrangementResult result = createOne(
      households()[NOTHING_DUE].Id,
      Date.today().addDays(10),
      120.00
    );
    Test.stopTest();

    Assert.areEqual(
      PaymentArrangementService.NOTHING_PAST_DUE,
      result.reasonCode,
      'Nothing is past due'
    );
  }

  @IsTest
  static void incompleteRequestsAreDeclined() {
    Id householdId = households()[PAST_DUE_190].Id;

    Test.startTest();
    List<PaymentArrangementService.ArrangementResult> results = PaymentArrangementService.createArrangements(
      new List<PaymentArrangementService.Request>{
        new PaymentArrangementService.Request(householdId, null, 190.00),
        new PaymentArrangementService.Request(
          householdId,
          Date.today().addDays(10),
          0
        ),
        new PaymentArrangementService.Request(
          null,
          Date.today().addDays(10),
          190.00
        ),
        null
      }
    );
    Test.stopTest();

    for (PaymentArrangementService.ArrangementResult result : results) {
      Assert.areEqual(
        StewardOutcome.INVALID_REQUEST,
        result.reasonCode,
        'Incomplete request'
      );
    }
    Assert.areEqual(0, promiseCount(householdId), 'Nothing saved');
    Assert.isTrue(
      PaymentArrangementService.createArrangements(null).isEmpty(),
      'A null list gives nothing'
    );
  }

  @IsTest
  static void aHouseholdOutOfReachIsNotFound() {
    Id householdId = households()[PAST_DUE_190].Id;
    User outsider = StewardTestData.createUserWithoutAccess();

    PaymentArrangementService.ArrangementResult result;
    Test.startTest();
    System.runAs(outsider) {
      result = checkOne(householdId, Date.today().addDays(10), 190.00);
    }
    Test.stopTest();

    Assert.areEqual(
      StewardOutcome.NOT_FOUND,
      result.reasonCode,
      'Not found, not refused'
    );
    Assert.isNull(result.pastDueBalance, 'Nothing about it is returned');
  }

  @IsTest
  static void checkingEligibilitySavesNothing() {
    Id householdId = households()[PAST_DUE_190].Id;

    Test.startTest();
    PaymentArrangementService.ArrangementResult result = checkOne(
      householdId,
      Date.today().addDays(10),
      190.00
    );
    Test.stopTest();

    Assert.areEqual(
      PaymentArrangementService.ELIGIBLE,
      result.reasonCode,
      'Eligible'
    );
    Assert.isNull(result.promiseId, 'No promise id');
    Assert.areEqual(0, promiseCount(householdId), 'Nothing saved');
  }

  @IsTest
  static void neverLeavesBehindAPromiseThatNeedsApproval() {
    List<Account> accounts = households();
    Integer accordsWindow = windowDays();
    Date beyondAccordsWindow = Date.today().addDays(accordsWindow + 10);
    // Make Steward's reading of the window wider than Accord's, so a promise passes Steward's
    // check but Accord's flow sends it for approval.
    PolicySettings.testOverrides.put(
      PolicySettings.PROMISE_WINDOW_DAYS,
      accordsWindow + 30
    );

    Test.startTest();
    List<PaymentArrangementService.ArrangementResult> results = PaymentArrangementService.createArrangements(
      new List<PaymentArrangementService.Request>{
        new PaymentArrangementService.Request(
          accounts[PAST_DUE_190].Id,
          beyondAccordsWindow,
          190.00
        ),
        new PaymentArrangementService.Request(
          accounts[PAST_DUE_120].Id,
          Date.today().addDays(5),
          120.00
        )
      }
    );
    Test.stopTest();

    Assert.areEqual(
      PaymentArrangementService.WOULD_NEED_APPROVAL,
      results[0].reasonCode,
      'Accord would have sent it for approval'
    );
    Assert.isNull(results[0].promiseId, 'No promise is reported');
    Assert.areEqual(
      0,
      promiseCount(accounts[PAST_DUE_190].Id),
      'Rolled back: nothing left for a supervisor to approve (GR-03)'
    );
    Assert.isNull(
      [
        SELECT Collection_Hold_Until__c
        FROM Account
        WHERE Id = :accounts[PAST_DUE_190].Id
      ]
      .Collection_Hold_Until__c,
      'No hold was set'
    );
    Assert.areEqual(
      StewardOutcome.COMPLETED,
      results[1].outcome,
      'The other arrangement still went through'
    );
    Assert.areEqual(
      'Active',
      [SELECT Status__c FROM Promise_to_Pay__c WHERE Id = :results[1].promiseId]
      .Status__c,
      'Saved again, Active'
    );
  }

  @IsTest
  static void onePromisePerHouseholdInABatch() {
    Id householdId = households()[PAST_DUE_190].Id;

    Test.startTest();
    List<PaymentArrangementService.ArrangementResult> results = PaymentArrangementService.createArrangements(
      new List<PaymentArrangementService.Request>{
        new PaymentArrangementService.Request(
          householdId,
          Date.today().addDays(10),
          190.00
        ),
        new PaymentArrangementService.Request(
          householdId,
          Date.today().addDays(12),
          190.00
        )
      }
    );
    Test.stopTest();

    Assert.areEqual(
      StewardOutcome.COMPLETED,
      results[0].outcome,
      'The first is saved'
    );
    Assert.areEqual(
      PaymentArrangementService.EXISTING_PROMISE,
      results[1].reasonCode,
      'The second is declined'
    );
    Assert.areEqual(1, promiseCount(householdId), 'One promise');
  }

  @IsTest
  static void theMinimumIsNeverBelowTheFullPastDueBalance() {
    Assert.areEqual(
      190.00,
      ArrangementEligibility.minimumAmount(190.00, 80),
      'A lower setting can\'t go under Accord\'s rule'
    );
    Assert.areEqual(
      209.00,
      ArrangementEligibility.minimumAmount(190.00, 110),
      'A higher setting raises the bar'
    );
    Assert.areEqual(
      190.00,
      ArrangementEligibility.minimumAmount(190.00, null),
      'No setting means the full balance'
    );
    Assert.areEqual(
      33.34,
      ArrangementEligibility.minimumAmount(33.333, 100),
      'Rounded up to the cent'
    );
  }

  @IsTest
  static void arranges200HouseholdsInOneCall() {
    List<StewardTestData.Household> many = StewardTestData.createHouseholds(
      200,
      StewardTestData.ACCOUNT_DELINQUENT
    );
    List<Billing_Statement__c> statements = new List<Billing_Statement__c>();
    List<PaymentArrangementService.Request> requests = new List<PaymentArrangementService.Request>();
    Set<Id> ids = new Set<Id>();
    for (StewardTestData.Household household : many) {
      statements.add(
        StewardTestData.statement(
          household,
          StewardTestData.monthStart(1),
          120.00,
          StewardTestData.STATEMENT_PAST_DUE
        )
      );
      requests.add(
        new PaymentArrangementService.Request(
          household.account.Id,
          Date.today().addDays(7),
          120.00
        )
      );
      ids.add(household.account.Id);
    }
    insert statements;

    Test.startTest();
    List<PaymentArrangementService.ArrangementResult> results = PaymentArrangementService.createArrangements(
      requests
    );
    Test.stopTest();

    for (PaymentArrangementService.ArrangementResult result : results) {
      Assert.areEqual(
        StewardOutcome.COMPLETED,
        result.outcome,
        'Each saved: ' + result.reasonCode + ' ' + result.failureDetail
      );
    }
    Assert.areEqual(
      200,
      [
        SELECT COUNT()
        FROM Promise_to_Pay__c
        WHERE Account__c IN :ids AND Status__c = 'Active'
      ],
      'Two hundred Active promises'
    );
  }
}
