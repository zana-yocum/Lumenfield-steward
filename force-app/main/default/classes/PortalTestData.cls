/**
 * Phase 4, NFR-03, S-16. Test data for the customer portal, on top of StewardTestData's households:
 * customer users for their primary contacts, the role the households' owner needs before any
 * customer can be created, and the internal Default Review case no customer may ever see.
 */
@IsTest
public class PortalTestData {
  public static final String DEFAULT_REVIEW_RECORD_TYPE = 'Default_Review';
  /**
   * Test customers get login licenses, so the org's member licenses stay free for the demo
   * customers.
   */
  public static final String CUSTOMER_PROFILE = 'Steward Customer Login';
  public static final String CUSTOMER_PERMISSION_SET = 'PS_Steward_Customer';

  private static Integer sequence = 0;
  // Keeps usernames unique when a test method adds customers to its @TestSetup ones.
  private static final String RUN = EncodingUtil.convertToHex(
      Crypto.generateAesKey(128)
    )
    .left(6)
    .toUpperCase();

  /**
   * Gives the running user a role if it has none. Salesforce won't create a customer user on an
   * account whose owner has no role, and the pipeline user has none. Call it before inserting the
   * households that will have customers.
   */
  public static void giveRunningUserARole() {
    User me = [
      SELECT Id, UserRoleId
      FROM User
      WHERE Id = :UserInfo.getUserId()
    ];
    if (me.UserRoleId != null) {
      return;
    }
    me.UserRoleId = [
      SELECT Id
      FROM UserRole
      WHERE PortalType = 'None'
      ORDER BY DeveloperName
      LIMIT 1
    ]
    .Id;
    // A separate context, so the user update doesn't collide with the households inserted next.
    System.runAs(new User(Id = UserInfo.getUserId())) {
      update me;
    }
  }

  /**
   * Inserts a customer user for each household's primary contact, with PS_Steward_Customer.
   * @param households whose customers; their owner needs a role (giveRunningUserARole)
   * @return the users, in the same order
   */
  public static List<User> createCustomers(
    List<StewardTestData.Household> households
  ) {
    return createCustomers(
      households,
      [
        SELECT Id
        FROM PermissionSet
        WHERE Name = :CUSTOMER_PERMISSION_SET
        LIMIT 1
      ]
      .Id
    );
  }

  /**
   * Inserts a customer user for each household's primary contact, with the given permission set.
   * @param households whose customers; their owner needs a role (giveRunningUserARole)
   * @param permissionSetId the permission set to assign, or null for none
   * @return the users, in the same order
   */
  public static List<User> createCustomers(
    List<StewardTestData.Household> households,
    Id permissionSetId
  ) {
    Id profileId = [
      SELECT Id
      FROM Profile
      WHERE Name = :CUSTOMER_PROFILE
      LIMIT 1
    ]
    .Id;
    List<User> customers = new List<User>();
    for (StewardTestData.Household household : households) {
      String suffix = nextSuffix();
      customers.add(
        new User(
          Alias = 'stwcust',
          ContactId = household.primaryContact.Id,
          Email = 'steward.customer.' + suffix + '@example.com',
          EmailEncodingKey = 'UTF-8',
          FirstName = 'Test',
          LastName = 'Customer ' + suffix,
          LanguageLocaleKey = 'en_US',
          LocaleSidKey = 'en_US',
          ProfileId = profileId,
          TimeZoneSidKey = 'America/Chicago',
          Username = 'steward.customer.' +
            suffix +
            '.' +
            Math.abs(Crypto.getRandomInteger()) +
            '@example.com'
        )
      );
    }
    System.runAs(new User(Id = UserInfo.getUserId())) {
      insert customers;
      if (permissionSetId != null) {
        List<PermissionSetAssignment> assignments = new List<PermissionSetAssignment>();
        for (User customer : customers) {
          assignments.add(
            new PermissionSetAssignment(
              AssigneeId = customer.Id,
              PermissionSetId = permissionSetId
            )
          );
        }
        insert assignments;
      }
    }
    return customers;
  }

  /**
   * Inserts a Default Review case on the household, as Accord's collections process opens one.
   * @param household whose review
   * @return the inserted case
   */
  public static Case insertDefaultReview(StewardTestData.Household household) {
    Case review = new Case(
      RecordTypeId = Schema.SObjectType.Case.getRecordTypeInfosByDeveloperName()
        .get(DEFAULT_REVIEW_RECORD_TYPE)
        .getRecordTypeId(),
      AccountId = household.account.Id,
      ContactId = household.primaryContact.Id,
      Origin = 'Phone',
      Subject = 'Default review: internal notes on the account'
    );
    insert review;
    return review;
  }

  private static String nextSuffix() {
    sequence++;
    return String.valueOf(sequence).leftPad(4, '0') + '-' + RUN;
  }
}
