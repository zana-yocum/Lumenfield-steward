// S-16. One-time, after the Phase 4 close-out deploy: saves every Billing Dispute case once, so
// Case_BeforeSave_StampCustomerHousehold stamps the household on the disputes that existed before
// it. The script doesn't name the field: no profile can see it, and anonymous Apex runs with the
// runner's field access. Safe to run again: a dispute already stamped is left as it is.
List<Case> disputes = [
  SELECT Id
  FROM Case
  WHERE RecordType.DeveloperName = 'Billing_Dispute'
];
update disputes;
System.debug(disputes.size());
