/**
 * ST-04, S-03. Proves policy values come from Accord's Policy_Setting__mdt records, and that a
 * missing or unusable setting stops the caller instead of falling back to a guess.
 */
@IsTest
private class PolicySettingsTest {
  @IsTest
  static void readsAccordsRecords() {
    Decimal window = PolicySettings.getNumber(
      PolicySettings.PROMISE_WINDOW_DAYS
    );

    Assert.areEqual(
      StewardTestData.policyNumber('Promise_Window_Days'),
      window,
      'The window is Accord\'s record'
    );
    Assert.areEqual(
      window.intValue(),
      PolicySettings.getWholeNumber(PolicySettings.PROMISE_WINDOW_DAYS),
      'A whole-number setting reads as an Integer'
    );
    Assert.isNotNull(
      PolicySettings.getNumber(
        PolicySettings.SELF_SERVICE_BROKEN_PROMISE_LIMIT
      ),
      'Steward\'s broken-promise limit exists'
    );
    Assert.isNotNull(
      PolicySettings.getNumber(PolicySettings.SELF_SERVICE_MIN_COVERAGE_PCT),
      'Steward\'s coverage percentage exists'
    );
  }

  @IsTest
  static void missingSettingStopsTheCaller() {
    try {
      PolicySettings.getNumber('Steward_Test_No_Such_Setting');
      Assert.fail('A missing setting must throw');
    } catch (PolicySettings.PolicySettingException e) {
      Assert.isTrue(
        e.getMessage().contains('Steward_Test_No_Such_Setting'),
        'The message names the setting: ' + e.getMessage()
      );
    }
    try {
      PolicySettings.getNumber(' ');
      Assert.fail('A blank name must throw');
    } catch (PolicySettings.PolicySettingException e) {
      Assert.isNotNull(e.getMessage(), 'A blank name throws');
    }
  }

  @IsTest
  static void wholeNumberSettingRejectsFractions() {
    PolicySettings.testOverrides.put('Steward_Test_Fraction', 1.5);

    try {
      PolicySettings.getWholeNumber('Steward_Test_Fraction');
      Assert.fail('A fraction must throw');
    } catch (PolicySettings.PolicySettingException e) {
      Assert.isTrue(
        e.getMessage().contains('whole number'),
        'The message says why: ' + e.getMessage()
      );
    }
  }

  @IsTest
  static void testOverrideWinsOverTheRecord() {
    PolicySettings.testOverrides.put(PolicySettings.PROMISE_WINDOW_DAYS, 45);

    Assert.areEqual(
      45,
      PolicySettings.getWholeNumber(PolicySettings.PROMISE_WINDOW_DAYS),
      'The test seam replaces the value'
    );
  }
}
