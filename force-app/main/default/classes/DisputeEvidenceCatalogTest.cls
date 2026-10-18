/**
 * ST-06. Proves the dispute reasons and evidence lists come from Accord's picklist and records,
 * with every requirement included and required items always ahead of optional ones.
 */
@IsTest
private class DisputeEvidenceCatalogTest {
  @IsTest
  static void listsAccordsReasonsWithEveryRequirement() {
    Map<String, Integer> expectedCounts = new Map<String, Integer>();
    for (
      Dispute_Evidence_Requirement__mdt requirement : Dispute_Evidence_Requirement__mdt.getAll()
        .values()
    ) {
      Integer soFar = expectedCounts.containsKey(requirement.Dispute_Reason__c)
        ? expectedCounts.get(requirement.Dispute_Reason__c)
        : 0;
      expectedCounts.put(requirement.Dispute_Reason__c, soFar + 1);
    }

    Test.startTest();
    List<DisputeEvidenceCatalog.ReasonOption> options = DisputeEvidenceCatalog.getReasons();
    Test.stopTest();

    Assert.areEqual(8, options.size(), 'The eight dispute reasons');
    for (DisputeEvidenceCatalog.ReasonOption option : options) {
      Assert.areEqual(
        expectedCounts.get(option.value),
        option.evidence.size(),
        'Every evidence record for ' + option.value
      );
      Assert.isTrue(
        String.isNotBlank(option.label),
        'A label to show the customer'
      );
      Boolean seenOptional = false;
      for (DisputeEvidenceCatalog.EvidenceItem item : option.evidence) {
        Assert.isFalse(
          seenOptional && item.required,
          'Required items come first for ' + option.value
        );
        seenOptional = seenOptional || !item.required;
      }
    }
  }

  @IsTest
  static void ordersRequiredItemsBeforeOptionalOnes() {
    List<DisputeEvidenceCatalog.EvidenceItem> promised = DisputeEvidenceCatalog.evidenceFor(
      'Promised Credit Not Applied'
    );

    Assert.areEqual(2, promised.size(), 'Two items');
    Assert.areEqual(
      'Signed agreement or addendum',
      promised[0].item,
      'Required: the signed agreement'
    );
    Assert.isTrue(promised[0].required, 'Marked required');
    Assert.areEqual(
      'Sales rep confirmation',
      promised[1].item,
      'Optional: the sales rep\'s confirmation'
    );
    Assert.isFalse(promised[1].required, 'Marked optional');
  }

  @IsTest
  static void knowsWhatIsAndIsNotAReason() {
    Assert.isTrue(
      DisputeEvidenceCatalog.isReason('Annual Escalator Increase'),
      'One of the eight'
    );
    Assert.isFalse(
      DisputeEvidenceCatalog.isReason('Just credit my account'),
      'Not a reason'
    );
    Assert.isFalse(DisputeEvidenceCatalog.isReason(null), 'Nothing');
    Assert.isTrue(
      DisputeEvidenceCatalog.evidenceFor('Not a reason').isEmpty(),
      'An unknown reason has no list'
    );
  }

  @IsTest
  static void callersCannotChangeTheCatalog() {
    List<DisputeEvidenceCatalog.EvidenceItem> first = DisputeEvidenceCatalog.evidenceFor(
      'Payment Not Posted'
    );
    first.clear();

    Assert.areEqual(
      2,
      DisputeEvidenceCatalog.evidenceFor('Payment Not Posted').size(),
      'Each caller gets its own copy'
    );
  }
}
