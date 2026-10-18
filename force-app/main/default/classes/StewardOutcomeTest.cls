/**
 * ST-11, GR-06. Proves every outcome code maps to its Agent_Action_Log__c label and that platform
 * errors come back as one readable line.
 */
@IsTest
private class StewardOutcomeTest {
  @IsTest
  static void mapsEveryOutcomeToItsLogLabel() {
    Assert.areEqual(
      'Completed',
      StewardOutcome.logLabel(StewardOutcome.COMPLETED),
      'COMPLETED label'
    );
    Assert.areEqual(
      'Declined by Policy',
      StewardOutcome.logLabel(StewardOutcome.DECLINED_POLICY),
      'DECLINED_POLICY label'
    );
    Assert.areEqual(
      'Handed Off',
      StewardOutcome.logLabel(StewardOutcome.HANDOFF),
      'HANDOFF label'
    );
    Assert.areEqual(
      'Failed',
      StewardOutcome.logLabel(StewardOutcome.FAILED),
      'FAILED label'
    );
  }

  @IsTest
  static void unknownOrMissingOutcomeHasNoLabel() {
    Assert.isNull(
      StewardOutcome.logLabel('SOMETHING_ELSE'),
      'An unknown code has no label'
    );
    Assert.isNull(StewardOutcome.logLabel(null), 'A null code has no label');
  }

  @IsTest
  static void describesSaveErrorsInOneLine() {
    Database.SaveResult failed = Database.insert(new Account(), false);

    String described = StewardOutcome.describeErrors(failed.getErrors());

    Assert.isFalse(failed.isSuccess(), 'An account with no name must fail');
    Assert.isTrue(
      described.contains('REQUIRED_FIELD_MISSING'),
      'The status code is included: ' + described
    );
    Assert.areEqual(
      '',
      StewardOutcome.describeErrors(null),
      'No errors give an empty line'
    );
  }

  @IsTest
  static void setsOutcomeAndReasonTogether() {
    StewardOutcome.Result result = new StewardOutcome.Result();

    result.setOutcome(StewardOutcome.DECLINED_POLICY, StewardOutcome.NOT_FOUND);

    Assert.areEqual(
      StewardOutcome.DECLINED_POLICY,
      result.outcome,
      'Outcome is set'
    );
    Assert.areEqual(
      StewardOutcome.NOT_FOUND,
      result.reasonCode,
      'Reason is set'
    );
  }
}
