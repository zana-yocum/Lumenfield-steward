/**
 * ST-04, S-03. The only class that reads Policy_Setting__mdt, so every limit, day count and
 * percentage Steward applies comes from Accord's policy records rather than from code. A setting
 * that's missing or blank stops the caller instead of falling back to a guess.
 */
public with sharing class PolicySettings {
  /** Accord's promise window, in days from today (ST-04). */
  public static final String PROMISE_WINDOW_DAYS = 'Promise_Window_Days';
  /** Broken promises in 90 days at which self-service hands off to a person (ST-04). */
  public static final String SELF_SERVICE_BROKEN_PROMISE_LIMIT = 'Self_Service_Broken_Promise_Limit';
  /** Share of the past-due balance an online arrangement must cover, in percent (ST-04). */
  public static final String SELF_SERVICE_MIN_COVERAGE_PCT = 'Self_Service_Min_Coverage_Pct';

  /**
   * Test seam. Lets a test show what happens when Steward's reading of a policy and Accord's
   * flow disagree. Only test code can set it; in production it stays empty.
   */
  @TestVisible
  private static Map<String, Decimal> testOverrides = new Map<String, Decimal>();

  /**
   * A policy setting's number value.
   * @param developerName the Policy_Setting__mdt record's developer name
   * @return its Number_Value__c
   * @throws PolicySettingException when the record is missing or has no number
   */
  public static Decimal getNumber(String developerName) {
    if (developerName != null && testOverrides.containsKey(developerName)) {
      return testOverrides.get(developerName);
    }
    Policy_Setting__mdt setting = String.isBlank(developerName)
      ? null
      : Policy_Setting__mdt.getInstance(developerName);
    if (setting == null || setting.Number_Value__c == null) {
      throw new PolicySettingException(
        'Policy setting ' +
          developerName +
          ' is missing or has no number value.'
      );
    }
    return setting.Number_Value__c;
  }

  /**
   * A policy setting that has to be a whole number, such as a day count or a limit.
   * @param developerName the Policy_Setting__mdt record's developer name
   * @return its Number_Value__c as an Integer
   * @throws PolicySettingException when the record is missing or the value has a fraction
   */
  public static Integer getWholeNumber(String developerName) {
    Decimal value = getNumber(developerName);
    if (value.setScale(0, System.RoundingMode.DOWN) != value) {
      throw new PolicySettingException(
        'Policy setting ' + developerName + ' has to be a whole number.'
      );
    }
    return value.intValue();
  }

  /** Thrown when a policy setting Steward depends on is missing or unusable. */
  public class PolicySettingException extends Exception {
  }
}
