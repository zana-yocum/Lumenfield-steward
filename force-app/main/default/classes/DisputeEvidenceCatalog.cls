/**
 * ST-06, ST-09. The eight dispute reasons and the evidence each one needs, read from Accord's
 * Case Dispute_Reason__c picklist and its Dispute_Evidence_Requirement__mdt records: the same
 * checklist the dispute specialists work from. Required items come first.
 */
public with sharing class DisputeEvidenceCatalog {
  private static Map<String, List<EvidenceItem>> evidenceCache;

  /** A dispute reason and its evidence list. */
  public class ReasonOption {
    @AuraEnabled
    public String value;
    @AuraEnabled
    public String label;
    @AuraEnabled
    public List<EvidenceItem> evidence = new List<EvidenceItem>();
  }

  /** One piece of evidence from Dispute_Evidence_Requirement__mdt. */
  public class EvidenceItem implements Comparable {
    @AuraEnabled
    public String item;
    @AuraEnabled
    public Boolean required;
    private transient String sortKey;

    /**
     * Copies one requirement record.
     * @param requirement the Dispute_Evidence_Requirement__mdt record
     */
    public EvidenceItem(Dispute_Evidence_Requirement__mdt requirement) {
      this.item = requirement.Evidence_Item__c;
      this.required = requirement.Required__c == true;
      this.sortKey = requirement.DeveloperName;
    }

    /**
     * Required items first, then in the order of the records' developer names.
     * @param other another EvidenceItem
     * @return negative, zero or positive, as Comparable expects
     */
    public Integer compareTo(Object other) {
      EvidenceItem that = (EvidenceItem) other;
      if (this.required != that.required) {
        return this.required ? -1 : 1;
      }
      return this.sortKey.compareTo(that.sortKey);
    }
  }

  /**
   * The active dispute reasons with their evidence lists, in the order Accord lists them.
   * @return one option per reason
   */
  public static List<ReasonOption> getReasons() {
    List<ReasonOption> options = new List<ReasonOption>();
    for (Schema.PicklistEntry entry : activeEntries()) {
      ReasonOption option = new ReasonOption();
      option.value = entry.getValue();
      option.label = entry.getLabel();
      option.evidence = evidenceFor(option.value);
      options.add(option);
    }
    return options;
  }

  /**
   * The evidence for one reason, required items first.
   * @param reason a Dispute_Reason__c value
   * @return a new list each call; empty for an unknown reason
   */
  public static List<EvidenceItem> evidenceFor(String reason) {
    List<EvidenceItem> items = evidenceByReason().get(reason);
    return items == null
      ? new List<EvidenceItem>()
      : new List<EvidenceItem>(items);
  }

  /**
   * Whether a value is one of the active dispute reasons.
   * @param reason the value to check
   * @return true when it's an active Dispute_Reason__c value
   */
  public static Boolean isReason(String reason) {
    if (String.isBlank(reason)) {
      return false;
    }
    for (Schema.PicklistEntry entry : activeEntries()) {
      if (entry.getValue() == reason) {
        return true;
      }
    }
    return false;
  }

  private static List<Schema.PicklistEntry> activeEntries() {
    List<Schema.PicklistEntry> active = new List<Schema.PicklistEntry>();
    for (
      Schema.PicklistEntry entry : Case.Dispute_Reason__c.getDescribe()
        .getPicklistValues()
    ) {
      if (entry.isActive()) {
        active.add(entry);
      }
    }
    return active;
  }

  private static Map<String, List<EvidenceItem>> evidenceByReason() {
    if (evidenceCache != null) {
      return evidenceCache;
    }
    evidenceCache = new Map<String, List<EvidenceItem>>();
    for (
      Dispute_Evidence_Requirement__mdt requirement : Dispute_Evidence_Requirement__mdt.getAll()
        .values()
    ) {
      if (String.isBlank(requirement.Dispute_Reason__c)) {
        continue;
      }
      if (!evidenceCache.containsKey(requirement.Dispute_Reason__c)) {
        evidenceCache.put(
          requirement.Dispute_Reason__c,
          new List<EvidenceItem>()
        );
      }
      evidenceCache.get(requirement.Dispute_Reason__c)
        .add(new EvidenceItem(requirement));
    }
    for (List<EvidenceItem> items : evidenceCache.values()) {
      items.sort();
    }
    return evidenceCache;
  }
}
