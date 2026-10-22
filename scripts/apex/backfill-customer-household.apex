// S-16. One-time, after the Phase 4b deploy: stamps Customer_Household__c on the Billing Dispute
// cases that existed before Case_BeforeSave_StampCustomerHousehold, so their customers can see
// them in the portal. New and changed cases are stamped by the flow. Safe to run again: it only
// touches disputes with no household yet. Default reviews are never stamped.
List<Case> disputes = [
  SELECT Id, AccountId
  FROM Case
  WHERE
    RecordType.DeveloperName = 'Billing_Dispute'
    AND Customer_Household__c = NULL
    AND AccountId != NULL
];
for (Case dispute : disputes) {
  dispute.Customer_Household__c = dispute.AccountId;
}
update disputes;
System.debug('Billing disputes stamped: ' + disputes.size());
