/**
 * NFR-03. IDs for tests that need a record that doesn't exist, such as a payment for a statement
 * that was never there. Built from the object's key prefix, so no ID is written into a test.
 */
@IsTest
public class TestIds {
  /**
   * A well-formed ID that no record has.
   * @param type the object
   * @return the ID
   */
  public static Id missing(Schema.SObjectType type) {
    return Id.valueOf(
      type.getDescribe(SObjectDescribeOptions.DEFERRED).getKeyPrefix() +
      '1'.leftPad(12, '0')
    );
  }
}
