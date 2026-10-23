/**
 * ST-09, S-20. The evidence part of a dispute summary: the items the dispute's reason needs,
 * required ones first (Accord's Dispute_Evidence_Requirement__mdt, through
 * DisputeEvidenceCatalog), against the files attached to the case. Files aren't tagged with the
 * item they're for, so the checklist calls every required item missing only when nothing is
 * attached; with files attached, matching them to items is the specialist's job.
 */
public with sharing class EvidenceChecklist {
  /** Added when nothing is attached. */
  public static final String ALL_MISSING = 'Every required item is still missing.';
  /** Added when there are files, or they can't be read. */
  public static final String SPECIALIST_CHECKS = 'Which required items any files cover isn\'t recorded; the specialist checks them.';

  /**
   * The evidence block for one dispute.
   * @param reason the dispute's Dispute_Reason__c
   * @param files the case's files, as a section
   * @return the block, starting with its heading
   */
  public static String forDispute(String reason, PromptSection files) {
    List<String> required = new List<String>();
    List<String> optional = new List<String>();
    for (
      DisputeEvidenceCatalog.EvidenceItem item : DisputeEvidenceCatalog.evidenceFor(
        reason
      )
    ) {
      if (item.required) {
        required.add(item.item);
      } else {
        optional.add(item.item);
      }
    }
    return String.join(
      new List<String>{
        'EVIDENCE FOR THIS REASON',
        'Required: ' + listed(required),
        'Optional: ' + listed(optional),
        files.toText(),
        files.isReadableAndEmpty() ? ALL_MISSING : SPECIALIST_CHECKS
      },
      '\n'
    );
  }

  /**
   * A file's name with its extension, unless the title already ends with it.
   * @param title the file's title
   * @param extension the file's extension, such as pdf
   * @return the name; "(untitled)" for a file with no title
   */
  public static String fileName(String title, String extension) {
    String name = String.isBlank(title) ? '(untitled)' : title;
    String suffix = String.isBlank(extension) ? '' : '.' + extension;
    return name.toLowerCase().endsWith(suffix.toLowerCase())
      ? name
      : name + suffix;
  }

  private static String listed(List<String> items) {
    return items.isEmpty() ? 'none listed.' : String.join(items, '; ') + '.';
  }
}
