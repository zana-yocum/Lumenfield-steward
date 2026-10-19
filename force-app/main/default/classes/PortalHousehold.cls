/**
 * ST-12, S-07, GR-01. The household of the customer who's logged in to the portal: the account of
 * the contact behind their user. Every portal controller starts here, and none of them takes an
 * account ID from the browser, so changing an ID on a page can't point a request at another
 * household. Anyone who isn't a customer, an admin previewing the site for example, has no
 * household, and the services answer that with nothing.
 */
public with sharing class PortalHousehold {
  /**
   * A failure to raise instead of answering, for the tests that prove every controller's failure
   * path (NFR-07). Always null outside a test.
   */
  @TestVisible
  private static Exception simulatedFailure;

  /**
   * The logged-in customer's household.
   * @return their account ID, or null when the user isn't a customer
   */
  public static Id current() {
    if (simulatedFailure != null) {
      throw simulatedFailure;
    }
    List<User> users = [
      SELECT AccountId
      FROM User
      WHERE Id = :UserInfo.getUserId()
      WITH USER_MODE
      LIMIT 1
    ];
    return users.isEmpty() ? null : users[0].AccountId;
  }
}
