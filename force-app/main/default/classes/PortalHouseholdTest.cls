/**
 * ST-12, S-07. Proves where every portal page's household comes from: a customer's household is
 * the account of the contact behind their user, and anyone who isn't a customer has none.
 */
@IsTest
private class PortalHouseholdTest {
  @TestSetup
  static void createData() {
    PortalTestData.giveRunningUserARole();
    StewardTestData.createHouseholds(2, StewardTestData.ACCOUNT_CURRENT);
  }

  @IsTest
  static void aCustomersHouseholdIsTheirContactsAccount() {
    List<StewardTestData.Household> households = households();
    List<User> customers = PortalTestData.createCustomers(households);
    Id first;
    Id second;
    Test.startTest();
    System.runAs(customers[0]) {
      first = PortalHousehold.current();
    }
    System.runAs(customers[1]) {
      second = PortalHousehold.current();
    }
    Test.stopTest();
    Assert.areEqual(
      households[0].account.Id,
      first,
      'The first customer gets their own household'
    );
    Assert.areEqual(
      households[1].account.Id,
      second,
      'And the second customer gets theirs'
    );
  }

  @IsTest
  static void someoneWhoIsNotACustomerHasNoHousehold() {
    User outsider = StewardTestData.createUserWithoutAccess();
    Id forAdmin;
    Id forOutsider;
    Test.startTest();
    forAdmin = PortalHousehold.current();
    System.runAs(outsider) {
      forOutsider = PortalHousehold.current();
    }
    Test.stopTest();
    Assert.isNull(forAdmin, 'An admin previewing the site has no household');
    Assert.isNull(forOutsider, 'Nor does any other internal user');
  }

  // The households from the setup, with their primary contacts, in name order.
  private static List<StewardTestData.Household> households() {
    List<StewardTestData.Household> result = new List<StewardTestData.Household>();
    for (Account account : [
      SELECT Id, (SELECT Id FROM Contacts LIMIT 1)
      FROM Account
      WHERE Name LIKE 'Steward Test Household%'
      ORDER BY Name
    ]) {
      StewardTestData.Household household = new StewardTestData.Household();
      household.account = account;
      household.primaryContact = account.Contacts[0];
      result.add(household);
    }
    return result;
  }
}
