/**
 * ST-08, ST-09. Proves a dispute's next open milestone is the one due soonest, written with its
 * due time in the reader's time zone, and that someone who can't read milestones is told so.
 */
@IsTest
private class SlaMilestonesTest {
  @TestSetup
  static void createData() {
    List<StewardTestData.Household> households = StewardTestData.createHouseholds(
      1,
      StewardTestData.ACCOUNT_DELINQUENT
    );
    Billing_Statement__c statement = StewardTestData.statement(
      households[0],
      StewardTestData.monthStart(2),
      120,
      StewardTestData.STATEMENT_PAST_DUE
    );
    insert statement;
    Entitlement sla = StewardTestData.entitlement(households[0]);
    sla.SlaProcessId = [
      SELECT Id
      FROM SlaProcess
      WHERE Name = 'Billing Dispute SLA' AND IsActive = TRUE
      LIMIT 1
    ]
    .Id;
    insert sla;
    StewardTestData.insertDispute(
      households[0],
      statement,
      'Payment Not Posted'
    );
  }

  @IsTest
  static void theNextMilestoneIsTheOneDueSoonest() {
    Case dispute = [SELECT Id FROM Case LIMIT 1];
    CaseMilestone soonest = [
      SELECT MilestoneType.Name, TargetDate, IsViolated
      FROM CaseMilestone
      WHERE CaseId = :dispute.Id AND IsCompleted = FALSE
      ORDER BY TargetDate ASC
      LIMIT 1
    ];

    Test.startTest();
    String next = SlaMilestones.nextFor(new Set<Id>{ dispute.Id })
      .get(dispute.Id);
    Test.stopTest();

    Assert.areEqual(
      soonest.MilestoneType.Name +
        ', due ' +
        PromptFormat.moment(soonest.TargetDate) +
        (soonest.IsViolated ? ' (missed).' : '.'),
      next,
      'Name, due time, and whether it was missed'
    );
  }

  @IsTest
  static void aCaseWithNoOpenMilestoneSaysSo() {
    Case dispute = [SELECT Id FROM Case LIMIT 1];
    // Any record with no milestones: the household itself.
    Id noMilestones = StewardTestData.existingHouseholds()[0].account.Id;

    Test.startTest();
    Map<Id, String> next = SlaMilestones.nextFor(
      new Set<Id>{ dispute.Id, noMilestones }
    );
    Map<Id, String> none = SlaMilestones.nextFor(new Set<Id>());
    Test.stopTest();

    Assert.areEqual(
      SlaMilestones.NONE_OPEN,
      next.get(noMilestones),
      'A record with no milestones has none open'
    );
    Assert.isTrue(none.isEmpty(), 'Nothing asked, nothing returned');
  }

  @IsTest
  static void someoneWhoCantReadMilestonesIsToldSo() {
    Case dispute = [SELECT Id FROM Case LIMIT 1];
    User outsider = StewardTestData.createUserWithoutAccess();
    String next;

    Test.startTest();
    System.runAs(outsider) {
      next = SlaMilestones.nextFor(new Set<Id>{ dispute.Id }).get(dispute.Id);
    }
    Test.stopTest();

    Assert.areEqual(SlaMilestones.NOT_AVAILABLE, next, 'Not guessed at');
  }
}
