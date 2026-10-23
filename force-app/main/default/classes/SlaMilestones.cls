/**
 * ST-08, ST-09. The next open SLA milestone on each billing dispute, as the briefing and the
 * dispute summary both write it: the milestone's name, when it's due in the reader's time zone,
 * and whether it's already been missed. Read in user mode; someone who can't read milestones is
 * told so instead of the summary failing.
 */
public with sharing class SlaMilestones {
  /** What a dispute with no open milestone says. */
  public static final String NONE_OPEN = 'none open.';
  /** What someone who can't read milestones is told. */
  public static final String NOT_AVAILABLE = 'not available to you.';

  /**
   * The next open milestone on each case.
   * @param caseIds billing disputes
   * @return one description per case ID, such as "Acknowledge, due Oct 21, 2026, 4:00 PM EDT
   *         (missed)."
   */
  public static Map<Id, String> nextFor(Set<Id> caseIds) {
    Map<Id, String> descriptions = new Map<Id, String>();
    if (caseIds == null || caseIds.isEmpty()) {
      return descriptions;
    }
    for (Id caseId : caseIds) {
      descriptions.put(caseId, NONE_OPEN);
    }
    try {
      Set<Id> described = new Set<Id>();
      for (CaseMilestone milestone : [
        SELECT Id, CaseId, MilestoneType.Name, TargetDate, IsViolated
        FROM CaseMilestone
        WHERE CaseId IN :caseIds AND IsCompleted = FALSE
        WITH USER_MODE
        ORDER BY TargetDate ASC
      ]) {
        if (described.add(milestone.CaseId)) {
          descriptions.put(milestone.CaseId, describe(milestone));
        }
      }
    } catch (QueryException notReadable) {
      for (Id caseId : caseIds) {
        descriptions.put(caseId, NOT_AVAILABLE);
      }
    }
    return descriptions;
  }

  private static String describe(CaseMilestone milestone) {
    return milestone.MilestoneType.Name +
      ', due ' +
      PromptFormat.moment(milestone.TargetDate) +
      (milestone.IsViolated ? ' (missed).' : '.');
  }
}
