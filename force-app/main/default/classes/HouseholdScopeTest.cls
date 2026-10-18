/**
 * ST-12, GR-01. Proves a household is in reach only when it's a Residential Agreement account the
 * running user can see, and that sharing, not the ID, decides it.
 */
@IsTest
private class HouseholdScopeTest {
  @TestSetup
  static void createData() {
    StewardTestData.createHousehold();
    insert new Account(
      Name = 'Steward Test Organization',
      RecordTypeId = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName()
        .get('Organization')
        .getRecordTypeId()
    );
  }

  @IsTest
  static void onlyResidentialAgreementAccountsAreHouseholds() {
    Account household = [
      SELECT Id
      FROM Account
      WHERE RecordType.DeveloperName = 'Residential_Agreement'
      LIMIT 1
    ];
    Account organization = [
      SELECT Id
      FROM Account
      WHERE RecordType.DeveloperName = 'Organization'
      LIMIT 1
    ];

    Set<Id> visible = HouseholdScope.visibleHouseholds(
      new Set<Id>{ household.Id, organization.Id }
    );

    Assert.isTrue(visible.contains(household.Id), 'The household is in reach');
    Assert.isFalse(
      visible.contains(organization.Id),
      'An Organization account is never a household'
    );
    Assert.isTrue(
      HouseholdScope.isVisible(household.Id),
      'isVisible agrees for the household'
    );
    Assert.isFalse(
      HouseholdScope.isVisible(organization.Id),
      'isVisible agrees for the organization'
    );
  }

  @IsTest
  static void nullAndEmptyInputsReachNothing() {
    Assert.isTrue(
      HouseholdScope.visibleHouseholds(null).isEmpty(),
      'Null reaches nothing'
    );
    Assert.isTrue(
      HouseholdScope.visibleHouseholds(new Set<Id>()).isEmpty(),
      'An empty set reaches nothing'
    );
    Assert.isTrue(
      HouseholdScope.visibleHouseholds(new Set<Id>{ null }).isEmpty(),
      'A null ID reaches nothing'
    );
    Assert.isFalse(HouseholdScope.isVisible(null), 'isVisible(null) is false');
  }

  @IsTest
  static void sharingDecidesWhatAUserCanReach() {
    Account household = [
      SELECT Id
      FROM Account
      WHERE RecordType.DeveloperName = 'Residential_Agreement'
      LIMIT 1
    ];
    User outsider = StewardTestData.createUserWithoutAccess();

    Boolean beforeSharing;
    System.runAs(outsider) {
      beforeSharing = HouseholdScope.isVisible(household.Id);
    }
    StewardTestData.shareRead(household.Id, outsider.Id);
    Boolean afterSharing;
    System.runAs(outsider) {
      afterSharing = HouseholdScope.isVisible(household.Id);
    }

    Assert.isFalse(
      beforeSharing,
      'Knowing the ID is not enough: the household is out of reach'
    );
    Assert.isTrue(afterSharing, 'Once shared, the household is in reach');
  }
}
