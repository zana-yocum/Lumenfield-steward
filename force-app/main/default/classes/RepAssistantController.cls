/**
 * ST-08, ST-09, ST-10, S-21. The rep assistant's buttons in the Collections Console: Briefing
 * and Follow-up Draft on a household, Dispute Summary on a billing dispute. Each method checks,
 * before any model runs, that the record is one the user can see and that the request has what
 * it needs, then runs the prompt template through PromptRunner as that user. The follow-up comes
 * back as an email for the standard composer, addressed and signed here so the model never sees
 * the customer's name or address. Nothing is sent from here.
 */
public with sharing class RepAssistantController {
  /** The briefing template's API name. */
  public static final String BRIEFING_TEMPLATE = 'Steward_Account_Briefing';
  /** The dispute summary template's API name. */
  public static final String DISPUTE_SUMMARY_TEMPLATE = 'Steward_Dispute_Summary';
  /** The follow-up template's API name. */
  public static final String FOLLOWUP_TEMPLATE = 'Steward_Followup_Draft';
  /** Reason code: no contact attempt from today to ground a follow-up in (ST-10). */
  public static final String NO_ATTEMPT_TODAY = 'NO_ATTEMPT_TODAY';
  /** Reason code: the model or the Trust Layer returned no text. */
  public static final String GENERATION_FAILED = 'GENERATION_FAILED';

  private static final String HOUSEHOLD_INPUT = 'Input:Household';
  private static final String DISPUTE_INPUT = 'Input:Dispute';
  // Outcomes where nobody on the account was reached.
  private static final Set<String> NOT_REACHED = new Set<String>{
    'No Answer',
    'Left Voicemail',
    'Wrong Number'
  };

  /** Text the model wrote, for the console to show. */
  public class Generated extends StewardOutcome.Result {
    @AuraEnabled
    public String text;
    /** What went wrong, for an internal user, when the outcome is FAILED. */
    @AuraEnabled
    public String detail;
  }

  /** A follow-up email for the composer to open. */
  public class FollowupEmail extends StewardOutcome.Result {
    /** The primary contact's email address; blank when the rep can't read it or there's none. */
    @AuraEnabled
    public String toAddress;
    @AuraEnabled
    public String subject;
    /** Greeting, the model's text and the sign-off, as escaped HTML paragraphs. */
    @AuraEnabled
    public String htmlBody;
    /** What went wrong, for an internal user, when the outcome is FAILED. */
    @AuraEnabled
    public String detail;
  }

  /**
   * A pre-call briefing on a household (ST-08).
   * @param accountId the household on the page
   * @return the briefing; NOT_FOUND for a household the user can't see
   */
  @AuraEnabled
  public static Generated briefing(Id accountId) {
    Generated result = new Generated();
    if (!HouseholdScope.isVisible(accountId)) {
      result.setOutcome(
        StewardOutcome.DECLINED_POLICY,
        StewardOutcome.NOT_FOUND
      );
      return result;
    }
    return generate(BRIEFING_TEMPLATE, HOUSEHOLD_INPUT, accountId);
  }

  /**
   * A first-pass summary of a billing dispute (ST-09).
   * @param caseId the dispute on the page
   * @return the summary; NOT_FOUND for anything but a billing dispute the user can see
   */
  @AuraEnabled
  public static Generated disputeSummary(Id caseId) {
    Generated result = new Generated();
    if (!DisputeSummaryPrompt.isVisibleDispute(caseId)) {
      result.setOutcome(
        StewardOutcome.DECLINED_POLICY,
        StewardOutcome.NOT_FOUND
      );
      return result;
    }
    return generate(DISPUTE_SUMMARY_TEMPLATE, DISPUTE_INPUT, caseId);
  }

  /**
   * A follow-up email after today's call, for the rep to edit and send (ST-10).
   * @param accountId the household on the page
   * @return the email; NO_ATTEMPT_TODAY until the rep logs today's contact attempt
   */
  @AuraEnabled
  public static FollowupEmail followupDraft(Id accountId) {
    FollowupEmail email = new FollowupEmail();
    if (!HouseholdScope.isVisible(accountId)) {
      email.setOutcome(
        StewardOutcome.DECLINED_POLICY,
        StewardOutcome.NOT_FOUND
      );
      return email;
    }
    Task attempt = FollowupDraftPrompt.latestAttemptToday(accountId);
    if (attempt == null) {
      email.setOutcome(StewardOutcome.DECLINED_POLICY, NO_ATTEMPT_TODAY);
      return email;
    }
    String body;
    try {
      body = PromptRunner.generate(
        FOLLOWUP_TEMPLATE,
        HOUSEHOLD_INPUT,
        accountId
      );
    } catch (Exception failure) {
      email.setOutcome(StewardOutcome.FAILED, GENERATION_FAILED);
      email.detail = failure.getMessage();
      return email;
    }
    Contact recipient = primaryContact(accountId);
    email.toAddress = recipient?.Email;
    email.subject = subjectFor(attempt.Contact_Outcome__c);
    email.htmlBody = toHtml(greeting(recipient?.FirstName), body);
    email.setOutcome(StewardOutcome.COMPLETED, null);
    return email;
  }

  private static Generated generate(
    String templateName,
    String inputName,
    Id recordId
  ) {
    Generated result = new Generated();
    try {
      result.text = PromptRunner.generate(templateName, inputName, recordId);
      result.setOutcome(StewardOutcome.COMPLETED, null);
    } catch (Exception failure) {
      result.setOutcome(StewardOutcome.FAILED, GENERATION_FAILED);
      result.detail = failure.getMessage();
    }
    return result;
  }

  // Read in user mode. A rep who can't read the contact's email gets an empty To line and picks
  // the recipient in the composer.
  private static Contact primaryContact(Id accountId) {
    try {
      Account household = [
        SELECT Id, Primary_Contact__r.FirstName, Primary_Contact__r.Email
        FROM Account
        WHERE Id = :accountId
        WITH USER_MODE
      ];
      return household.Primary_Contact__r;
    } catch (QueryException notReadable) {
      return null;
    }
  }

  @TestVisible
  private static String subjectFor(String outcome) {
    if (outcome == FollowupDraftPrompt.PROMISE_MADE) {
      return System.Label.Steward_Rep_Subject_Promise;
    }
    return NOT_REACHED.contains(outcome)
      ? System.Label.Steward_Rep_Subject_Missed
      : System.Label.Steward_Rep_Subject_Call;
  }

  @TestVisible
  private static String greeting(String firstName) {
    return String.isBlank(firstName)
      ? System.Label.Steward_Rep_Greeting_Plain
      : String.format(
          System.Label.Steward_Rep_Greeting,
          new List<Object>{ firstName }
        );
  }

  // Every part is escaped: the model's text goes into the composer as text, never as markup.
  @TestVisible
  private static String toHtml(String greeting, String body) {
    List<String> paragraphs = new List<String>{ paragraph(greeting) };
    for (String part : body.trim().split('\\n\\s*\\n')) {
      if (String.isNotBlank(part)) {
        paragraphs.add(paragraph(part));
      }
    }
    paragraphs.add(
      paragraph(
        System.Label.Steward_Rep_Signoff +
          '\n' +
          UserInfo.getName() +
          '\n' +
          UserInfo.getOrganizationName()
      )
    );
    return String.join(paragraphs, '');
  }

  private static String paragraph(String text) {
    return '<p>' + text.trim().escapeHtml4().replace('\n', '<br>') + '</p>';
  }
}
