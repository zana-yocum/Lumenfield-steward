// S-04, S-18. One-time, after the Phase 4b deploy: makes the three demo households' primary
// contacts customer users, on the Steward Customer profile with PS_Steward_Customer. All data is
// invented, and usernames and emails are on example.com. No welcome email is sent. Safe to run
// again: a contact that already has a user is skipped.
List<String> households = new List<String>{
  'Sandra Barnett Household',
  'Tanya Lattimore Household',
  'Angela Coffey Household'
};
Id profileId = [SELECT Id FROM Profile WHERE Name = 'Steward Customer' LIMIT 1].Id;
Id permissionSetId = [
  SELECT Id
  FROM PermissionSet
  WHERE Name = 'PS_Steward_Customer'
  LIMIT 1
]
.Id;
Set<Id> haveUsers = new Set<Id>();
for (User existing : [SELECT ContactId FROM User WHERE ContactId != NULL]) {
  haveUsers.add(existing.ContactId);
}
List<User> customers = new List<User>();
for (Account household : [
  SELECT Primary_Contact__c, Primary_Contact__r.FirstName, Primary_Contact__r.LastName
  FROM Account
  WHERE Name IN :households AND Primary_Contact__c != NULL
]) {
  if (haveUsers.contains(household.Primary_Contact__c)) {
    continue;
  }
  String first = household.Primary_Contact__r.FirstName;
  String last = household.Primary_Contact__r.LastName;
  String handle = (first + '.' + last).toLowerCase().replaceAll('[^a-z.]', '');
  customers.add(
    new User(
      ContactId = household.Primary_Contact__c,
      ProfileId = profileId,
      FirstName = first,
      LastName = last,
      Email = handle + '@example.com',
      Username = handle + '.lumenfield@example.com',
      Alias = (first.left(1) + last).toLowerCase().left(8),
      CommunityNickname = handle.left(40),
      TimeZoneSidKey = 'America/New_York',
      LocaleSidKey = 'en_US',
      LanguageLocaleKey = 'en_US',
      EmailEncodingKey = 'UTF-8'
    )
  );
}
Database.DMLOptions options = new Database.DMLOptions();
options.EmailHeader.triggerUserEmail = false;
Database.insert(customers, options);
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
System.debug('Customer users created: ' + customers.size());
