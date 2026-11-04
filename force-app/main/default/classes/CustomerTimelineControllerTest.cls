/**
 * ST-15, ST-12, NFR-02, NFR-07. Proves the customer timeline shows one household's six kinds of
 * event newest first, pages without repeating or skipping, filters by kind, and shows each person
 * only what they can read: a household out of reach is not found, a customer always gets their own
 * household and no credits or commitments, and a field nobody granted comes back empty.
 *
 * The first household's history, newest first: a promise due next week; a dispute opened and a
 * $25 credit posted today; a $40 payment and the statement due at the start of last month; a $120
 * payment and the statement due a month before that; and a commitment signed a year ago. It also
 * has a $10 credit still in draft, which isn't history yet. The second household has one $95
 * statement.
 */
@IsTest
private class CustomerTimelineControllerTest {
  @TestSetup
  static void createData() {
    PortalTestData.giveRunningUserARole();
    List<StewardTestData.Household> households = StewardTestData.createHouseholds(
      2,
      StewardTestData.ACCOUNT_DELINQUENT
    );
    StewardTestData.Household first = households[0];
    List<Billing_Statement__c> statements = new List<Billing_Statement__c>{
      StewardTestData.statement(
        first,
        StewardTestData.monthStart(2),
        120.00,
        StewardTestData.STATEMENT_PAID
      ),
      StewardTestData.statement(
        first,
        StewardTestData.monthStart(1),
        120.00,
        StewardTestData.STATEMENT_PAST_DUE
      ),
      StewardTestData.statement(
        households[1],
        StewardTestData.monthStart(1),
        95.00,
        StewardTestData.STATEMENT_PAST_DUE
      )
    };
    insert statements;
    insert new List<Payment__c>{
      StewardTestData.payment(
        statements[0],
        120.00,
        StewardTestData.monthStart(2).addDays(-1)
      ),
      StewardTestData.payment(
        statements[1],
        40.00,
        StewardTestData.monthStart(1).addDays(-1)
      )
    };
    insert new List<Adjustment__c>{
      StewardTestData.credit(statements[1], 25.00, 'Goodwill Credit', 'Posted'),
      StewardTestData.credit(
        statements[1],
        10.00,
        'Billing Correction',
        'Draft'
      )
    };
    insert StewardTestData.promise(
      first,
      Date.today().addDays(7),
      80.00,
      'Active'
    );
    StewardTestData.insertDispute(first, statements[1], 'Payment Not Posted');
    Opportunity deal = StewardTestData.deal(first);
    deal.CloseDate = Date.today().addYears(-1);
    insert deal;
    insert StewardTestData.commitment(
      deal,
      'Promotional Credit',
      100.00,
      null,
      'A $100 welcome credit on the first statement.',
      'Applied'
    );
  }

  @IsTest
  static void aHouseholdsHistoryComesNewestFirstAcrossEveryKind() {
    Id household = StewardTestData.existingHouseholds()[0].account.Id;

    Test.startTest();
    CustomerTimelineController.TimelinePage page = CustomerTimelineController.getTimeline(
      household,
      null,
      null
    );
    Test.stopTest();

    Assert.areEqual(
      StewardOutcome.COMPLETED,
      page.outcome,
      'Completed: ' + page.reasonCode
    );
    Assert.areEqual(
      new List<String>{
        CustomerTimelineController.STATEMENT,
        CustomerTimelineController.PAYMENT,
        CustomerTimelineController.PROMISE,
        CustomerTimelineController.DISPUTE,
        CustomerTimelineController.CREDIT,
        CustomerTimelineController.COMMITMENT
      },
      page.availableKinds,
      'Every kind, for someone who can read them all'
    );
    Assert.areEqual(8, page.events.size(), 'Every event fits on one page');
    Assert.isNull(page.nextCursor, 'Nothing more');
    for (Integer i = 1; i < page.events.size(); i++) {
      Assert.isTrue(
        page.events[i - 1].eventDate >= page.events[i].eventDate,
        'Newest first: ' + JSON.serialize(page.events)
      );
    }
    Assert.areEqual(
      CustomerTimelineController.PROMISE,
      page.events[0].kind,
      'The promise due next week leads'
    );
    Assert.areEqual(80.00, page.events[0].amount, 'Its amount');
    Assert.areEqual(
      CustomerTimelineController.DISPUTE,
      page.events[1].kind,
      'On the same day, the dispute comes before the credit'
    );
    Assert.areEqual(
      CustomerTimelineController.CREDIT,
      page.events[2].kind,
      'The posted credit'
    );
    Assert.areEqual(25.00, page.events[2].amount, 'Not the $10 draft');
    Assert.areEqual(
      CustomerTimelineController.COMMITMENT,
      page.events[7].kind,
      'The commitment from signing is the oldest'
    );
    Assert.areEqual('Promotional Credit', page.events[7].detail, 'Its type');
  }

  @IsTest
  static void aKindPastTheOffsetLimitKeepsItsPlace() {
    Id household = StewardTestData.existingHouseholds()[0].account.Id;
    Map<String, Integer> offsets = TimelineCursor.parse(
      '{"STATEMENT":' + (CustomerTimelineController.MAX_OFFSET + 1) + '}'
    );
    CustomerTimelineController.TimelinePage page = new CustomerTimelineController.TimelinePage();

    new TimelineReader(household, 1).fill(page, null, offsets);

    Assert.areEqual(1, page.events.size(), 'One to a page');
    Assert.areNotEqual(
      CustomerTimelineController.STATEMENT,
      page.events[0].kind,
      'Statements stopped at the limit'
    );
    Map<String, Integer> next = TimelineCursor.parse(page.nextCursor);
    Assert.areEqual(
      CustomerTimelineController.MAX_OFFSET + 1,
      next.get(CustomerTimelineController.STATEMENT),
      'Their count is kept, so they never start again from the top'
    );
    Assert.areEqual(
      1,
      next.get(CustomerTimelineController.PROMISE),
      'The promise shown is counted'
    );
  }

  @IsTest
  static void aStatementCarriesItsFigures() {
    Id household = StewardTestData.existingHouseholds()[0].account.Id;

    CustomerTimelineController.TimelinePage page = CustomerTimelineController.getTimeline(
      household,
      new List<String>{ CustomerTimelineController.STATEMENT },
      null
    );

    Assert.areEqual(2, page.events.size(), 'Only statements');
    CustomerTimelineController.TimelineEvent latest = page.events[0];
    // Accord's flows move the balance and status as payments, credits and disputes land, so the
    // event is checked against the statement as Accord stores it.
    Billing_Statement__c stored = [
      SELECT Name, Balance__c, Status__c
      FROM Billing_Statement__c
      WHERE Id = :latest.recordId
      WITH SYSTEM_MODE
    ];
    Assert.areEqual(StewardTestData.monthStart(1), latest.dueDate, 'Due date');
    Assert.areEqual(120.00, latest.amount, 'Amount due');
    Assert.areEqual(stored.Balance__c, latest.balance, 'Balance');
    Assert.isNotNull(latest.balance, 'A balance to show');
    Assert.areEqual(stored.Status__c, latest.status, 'Status');
    Assert.areEqual(stored.Name, latest.name, 'Its number');
    Assert.isTrue(latest.name.startsWith('STMT-'), 'Accord\'s numbering');
  }

  @IsTest
  static void pagesNeitherRepeatNorSkip() {
    StewardTestData.Household second = StewardTestData.existingHouseholds()[1];
    List<Billing_Statement__c> statements = new List<Billing_Statement__c>();
    for (Integer i = 2; i < 200; i++) {
      statements.add(
        StewardTestData.statement(
          second,
          StewardTestData.monthStart(i),
          95.00,
          StewardTestData.STATEMENT_PAID
        )
      );
    }
    insert statements;

    Test.startTest();
    Set<Id> seen = new Set<Id>();
    Date previous;
    String cursor;
    Integer pages = 0;
    do {
      CustomerTimelineController.TimelinePage page = CustomerTimelineController.getTimeline(
        second.account.Id,
        new List<String>{ CustomerTimelineController.STATEMENT },
        cursor
      );
      Assert.areEqual(StewardOutcome.COMPLETED, page.outcome, 'Page ' + pages);
      for (CustomerTimelineController.TimelineEvent event : page.events) {
        Assert.isTrue(seen.add(event.recordId), 'Never repeated');
        Assert.isTrue(
          previous == null || event.eventDate <= previous,
          'Still newest first across pages'
        );
        previous = event.eventDate;
      }
      cursor = page.nextCursor;
      pages++;
    } while (cursor != null);
    Test.stopTest();

    Assert.areEqual(199, seen.size(), 'All 199 statements, none skipped');
    Assert.areEqual(10, pages, 'Twenty to a page');
  }

  @IsTest
  static void filteringShowsOnlyTheKindsAskedFor() {
    Id household = StewardTestData.existingHouseholds()[0].account.Id;

    CustomerTimelineController.TimelinePage page = CustomerTimelineController.getTimeline(
      household,
      new List<String>{
        CustomerTimelineController.PAYMENT,
        CustomerTimelineController.DISPUTE
      },
      null
    );

    Assert.areEqual(3, page.events.size(), 'Two payments and the dispute');
    for (CustomerTimelineController.TimelineEvent event : page.events) {
      Assert.isTrue(
        event.kind == CustomerTimelineController.PAYMENT ||
          event.kind == CustomerTimelineController.DISPUTE,
        'Only what was asked for: ' + event.kind
      );
    }
    Assert.areEqual(
      6,
      page.availableKinds.size(),
      'The filter still offers every kind'
    );
  }

  @IsTest
  static void aHouseholdOutOfReachIsNotFound() {
    Id household = StewardTestData.existingHouseholds()[0].account.Id;
    User outsider = StewardTestData.createUserWithoutAccess();

    CustomerTimelineController.TimelinePage page;
    System.runAs(outsider) {
      page = CustomerTimelineController.getTimeline(household, null, null);
    }

    Assert.areEqual(StewardOutcome.DECLINED_POLICY, page.outcome, 'Declined');
    Assert.areEqual(StewardOutcome.NOT_FOUND, page.reasonCode, 'Not found');
    Assert.isTrue(page.events.isEmpty(), 'Nothing comes back');
  }

  @IsTest
  static void aCustomerGetsTheirOwnHouseholdWhateverThePagePasses() {
    List<StewardTestData.Household> households = StewardTestData.existingHouseholds();
    List<User> customers = PortalTestData.createCustomers(households);

    CustomerTimelineController.TimelinePage page;
    System.runAs(customers[0]) {
      page = CustomerTimelineController.getTimeline(
        households[1].account.Id,
        null,
        null
      );
    }

    Assert.areEqual(
      StewardOutcome.COMPLETED,
      page.outcome,
      'Completed: ' + page.reasonCode
    );
    Assert.areEqual(
      new List<String>{
        CustomerTimelineController.STATEMENT,
        CustomerTimelineController.PAYMENT,
        CustomerTimelineController.PROMISE,
        CustomerTimelineController.DISPUTE
      },
      page.availableKinds,
      'No credits or commitments, which customers can\'t read'
    );
    Assert.areEqual(
      6,
      page.events.size(),
      'The first household\'s two statements, two payments, promise and dispute'
    );
    for (CustomerTimelineController.TimelineEvent event : page.events) {
      Assert.areNotEqual(
        95.00,
        event.amount,
        'Nothing of the second household\'s'
      );
    }
  }

  @IsTest
  static void aFieldNobodyGrantedComesBackEmpty() {
    Id household = StewardTestData.existingHouseholds()[0].account.Id;
    User reader = StewardTestData.createUserWithoutAccess();
    System.runAs(new User(Id = UserInfo.getUserId())) {
      PermissionSet onlyDates = new PermissionSet(
        Name = 'Steward_Timeline_Test_Dates_Only',
        Label = 'Steward Timeline Test Dates Only'
      );
      insert onlyDates;
      insert new ObjectPermissions(
        ParentId = onlyDates.Id,
        SobjectType = 'Billing_Statement__c',
        PermissionsRead = true
      );
      insert new FieldPermissions(
        ParentId = onlyDates.Id,
        SobjectType = 'Billing_Statement__c',
        Field = 'Billing_Statement__c.Statement_Date__c',
        PermissionsRead = true
      );
      insert new PermissionSetAssignment(
        AssigneeId = reader.Id,
        PermissionSetId = onlyDates.Id
      );
    }
    StewardTestData.shareRead(household, reader.Id);

    CustomerTimelineController.TimelinePage page;
    System.runAs(reader) {
      page = CustomerTimelineController.getTimeline(household, null, null);
    }

    Assert.areEqual(
      new List<String>{ CustomerTimelineController.STATEMENT },
      page.availableKinds,
      'Only the kind this person can read'
    );
    Assert.areEqual(2, page.events.size(), 'Both statements');
    Assert.isNotNull(page.events[0].eventDate, 'The date, which was granted');
    Assert.isNull(page.events[0].amount, 'No amount, which wasn\'t');
    Assert.isNull(page.events[0].balance, 'No balance');
    Assert.isNull(page.events[0].status, 'No status');
  }

  @IsTest
  static void aCursorThatIsntOneIsRefused() {
    Id household = StewardTestData.existingHouseholds()[0].account.Id;

    CustomerTimelineController.TimelinePage page = CustomerTimelineController.getTimeline(
      household,
      null,
      'not a cursor'
    );

    Assert.areEqual(StewardOutcome.DECLINED_POLICY, page.outcome, 'Declined');
    Assert.areEqual(
      StewardOutcome.INVALID_REQUEST,
      page.reasonCode,
      'Invalid request'
    );
  }

  @IsTest
  static void aFailureGivesAReferenceNotTheError() {
    Id household = StewardTestData.existingHouseholds()[0].account.Id;
    CustomerTimelineController.simulatedFailure = new QueryException(
      'Simulated failure'
    );

    CustomerTimelineController.TimelinePage page = CustomerTimelineController.getTimeline(
      household,
      null,
      null
    );

    Assert.areEqual(StewardOutcome.FAILED, page.outcome, 'Failed');
    Assert.isNotNull(page.reference, 'A number to quote');
    Assert.isTrue(page.events.isEmpty(), 'No events');
  }
}
