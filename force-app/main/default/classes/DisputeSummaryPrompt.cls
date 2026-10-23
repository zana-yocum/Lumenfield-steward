/**
 * ST-09, S-20. The data behind the Steward_Dispute_Summary prompt template: one billing dispute's
 * reason, status and disputed statement, what the customer wrote, the commitments on the
 * household, the evidence the reason needs against the files attached, any sales input, and the
 * next SLA milestone. Prompt Builder runs it as the specialist who clicked Dispute Summary, and
 * every query is in user mode. A part the specialist can't read says so instead of failing the
 * summary. The customer's words, comments and file names are fenced as quoted text: a dispute
 * description can arrive through the agent, so it's untrusted by design.
 */
// Prompt Builder matches these names: the template's input is Dispute, and the text it merges is
// Prompt.
@SuppressWarnings('PMD.FieldNamingConventions')
public with sharing class DisputeSummaryPrompt {
  /** What the template receives for a case that isn't a billing dispute the person can see. */
  public static final String NO_ACCESS = 'NO ACCESS: this billing dispute isn\'t available to the person asking.';
  /** What a part the person can't read says. */
  public static final String NOT_AVAILABLE = PromptSection.NOT_AVAILABLE;
  /** The reason that makes a commitment worth flagging. */
  public static final String PROMISED_CREDIT_REASON = 'Promised Credit Not Applied';
  /** Added to a commitment that could be the credit a Promised Credit Not Applied dispute means. */
  public static final String MAY_MATCH = ' [May match this dispute: not marked Applied.]';

  @TestVisible
  private static final Integer MAX_COMMENTS = 5;
  private static final Integer MAX_DESCRIPTION_LENGTH = 1500;
  private static final Integer MAX_COMMENT_LENGTH = 500;
  private static final Integer MAX_TITLE_LENGTH = 120;
  private static final String DISPUTE_RECORD_TYPE = 'Billing_Dispute';
  private static final Set<String> UNAPPLIED_COMMITMENT_STATUSES = new Set<String>{
    'Recorded',
    'Disputed'
  };

  /** The template's input. */
  public class Request {
    @InvocableVariable(label='Dispute' required=true)
    public Case Dispute;
  }

  /** The text Prompt Builder merges into the template. */
  public class Response {
    @InvocableVariable(label='Prompt')
    public String Prompt;
  }

  /**
   * Prompt Builder's entry point for Steward_Dispute_Summary.
   * @param requests one per generation, each with the case from the page
   * @return the summary data for each request, in the same order
   */
  @InvocableMethod(
    label='Steward dispute summary data'
    description='The facts behind the Steward_Dispute_Summary prompt template, read with the running user\'s access.'
    CapabilityType='FlexTemplate://Steward_Dispute_Summary'
  )
  public static List<Response> getPrompt(List<Request> requests) {
    List<Id> caseIds = new List<Id>();
    for (Request request : requests) {
      caseIds.add(request?.Dispute?.Id);
    }
    List<Response> responses = new List<Response>();
    for (
      String text : PromptFormat.inOrder(
        caseIds,
        build(new Set<Id>(caseIds)),
        NO_ACCESS
      )
    ) {
      Response response = new Response();
      response.Prompt = text;
      responses.add(response);
    }
    return responses;
  }

  /**
   * Whether a case is a billing dispute the running user can see.
   * @param caseId the case
   * @return true when the user can read it and it's a Billing Dispute
   */
  public static Boolean isVisibleDispute(Id caseId) {
    return caseId != null && !visibleDisputes(new Set<Id>{ caseId }).isEmpty();
  }

  /**
   * The summary data for each billing dispute the running user can see.
   * @param caseIds the cases
   * @return the text for each visible dispute; anything else is left out
   */
  public static Map<Id, String> build(Set<Id> caseIds) {
    Map<Id, Case> disputes = visibleDisputes(caseIds);
    Map<Id, String> texts = new Map<Id, String>();
    if (disputes.isEmpty()) {
      return texts;
    }
    Map<Id, String> words = customerWords(disputes.keySet());
    Map<Id, Billing_Statement__c> statements = statements(disputes.values());
    Map<Id, List<Commitment__c>> commitments = commitmentsByHousehold(
      disputes.values()
    );
    Map<Id, PromptSection> files = files(disputes.keySet());
    Map<Id, PromptSection> comments = comments(disputes.keySet());
    Map<Id, String> milestones = SlaMilestones.nextFor(disputes.keySet());

    for (Case dispute : disputes.values()) {
      texts.put(
        dispute.Id,
        String.join(
          new List<String>{
            'As of: ' + PromptFormat.day(Date.today()),
            'Case: ' + dispute.CaseNumber,
            'Status: ' + dispute.Status,
            'Opened: ' + PromptFormat.day(dispute.CreatedDate.date()),
            'Reason: ' + PromptFormat.orNotRecorded(dispute.Dispute_Reason__c),
            'Description (the customer\'s account of the dispute, as recorded): ' +
            words.get(dispute.Id),
            '',
            'DISPUTED STATEMENT',
            RecordLines.disputedStatement(
              statements.get(dispute.Disputed_Statement__c)
            ),
            '',
            commitmentSection(
                dispute,
                commitments.get(dispute.Disputed_Statement__r?.Account__c)
              )
              .toText(),
            '',
            EvidenceChecklist.forDispute(
              dispute.Dispute_Reason__c,
              files.get(dispute.Id)
            ),
            '',
            'SALES INPUT',
            'Requested: ' +
            PromptFormat.momentOr(dispute.Sales_Input_Requested__c, 'no') +
            '.',
            comments.get(dispute.Id).toText(),
            '',
            'NEXT SLA MILESTONE',
            milestones.get(dispute.Id)
          },
          '\n'
        )
      );
    }
    return texts;
  }

  // Someone who can't read cases at all sees no disputes, the same as one they can't see.
  private static Map<Id, Case> visibleDisputes(Set<Id> caseIds) {
    if (caseIds == null || caseIds.isEmpty()) {
      return new Map<Id, Case>();
    }
    try {
      return new Map<Id, Case>(
        [
          SELECT
            Id,
            CaseNumber,
            Status,
            CreatedDate,
            Dispute_Reason__c,
            Disputed_Statement__c,
            Disputed_Statement__r.Account__c,
            Sales_Input_Requested__c
          FROM Case
          WHERE
            Id IN :caseIds
            AND RecordType.DeveloperName = :DISPUTE_RECORD_TYPE
          WITH USER_MODE
        ]
      );
    } catch (QueryException notReadable) {
      return new Map<Id, Case>();
    }
  }

  // The customer's own words. Collections reps can't read the description; dispute specialists
  // and supervisors can, through PS_Steward_Dispute_Specialist (S-22).
  private static Map<Id, String> customerWords(Set<Id> caseIds) {
    Map<Id, String> words = new Map<Id, String>();
    try {
      for (Case dispute : [
        SELECT Id, Description
        FROM Case
        WHERE Id IN :caseIds
        WITH USER_MODE
      ]) {
        words.put(
          dispute.Id,
          String.isBlank(dispute.Description)
            ? 'nothing written.'
            : PromptFormat.quoted(dispute.Description, MAX_DESCRIPTION_LENGTH)
        );
      }
    } catch (QueryException notReadable) {
      for (Id caseId : caseIds) {
        words.put(caseId, NOT_AVAILABLE);
      }
    }
    return words;
  }

  private static Map<Id, Billing_Statement__c> statements(List<Case> disputes) {
    Set<Id> statementIds = new Set<Id>();
    for (Case dispute : disputes) {
      statementIds.add(dispute.Disputed_Statement__c);
    }
    return new Map<Id, Billing_Statement__c>(
      [
        SELECT
          Id,
          Name,
          Statement_Date__c,
          Due_Date__c,
          Amount_Due__c,
          Amount_Paid__c,
          Credits_Applied__c,
          Balance__c,
          Status__c
        FROM Billing_Statement__c
        WHERE Id IN :statementIds
        WITH USER_MODE
      ]
    );
  }

  // Found through the disputed statement's household: Case.AccountId is one more field
  // collections personas can't read, and the statement's account is the same household.
  private static Map<Id, List<Commitment__c>> commitmentsByHousehold(
    List<Case> disputes
  ) {
    Set<Id> householdIds = new Set<Id>();
    for (Case dispute : disputes) {
      householdIds.add(dispute.Disputed_Statement__r?.Account__c);
    }
    Map<Id, List<Commitment__c>> byHousehold = new Map<Id, List<Commitment__c>>();
    for (Commitment__c commitment : [
      SELECT
        Id,
        Account__c,
        Type__c,
        Value__c,
        Months_Covered__c,
        Status__c,
        Terms__c
      FROM Commitment__c
      WHERE Account__c IN :householdIds
      WITH USER_MODE
      ORDER BY CreatedDate ASC
    ]) {
      if (!byHousehold.containsKey(commitment.Account__c)) {
        byHousehold.put(commitment.Account__c, new List<Commitment__c>());
      }
      byHousehold.get(commitment.Account__c).add(commitment);
    }
    return byHousehold;
  }

  private static PromptSection commitmentSection(
    Case dispute,
    List<Commitment__c> commitments
  ) {
    PromptSection section = new PromptSection(
      'COMMITMENTS ON THE HOUSEHOLD',
      'None.',
      null
    );
    Boolean promisedCredit =
      dispute.Dispute_Reason__c == PROMISED_CREDIT_REASON;
    for (Commitment__c commitment : commitments ?? new List<Commitment__c>()) {
      Boolean mayMatch =
        promisedCredit &&
        UNAPPLIED_COMMITMENT_STATUSES.contains(commitment.Status__c);
      section.add(
        RecordLines.commitment(commitment, mayMatch ? MAY_MATCH : null)
      );
    }
    return section;
  }

  private static Map<Id, PromptSection> files(Set<Id> caseIds) {
    Map<Id, PromptSection> byCase = new Map<Id, PromptSection>();
    for (Id caseId : caseIds) {
      byCase.put(caseId, new PromptSection('Files attached:', 'none.', null));
    }
    try {
      for (ContentDocumentLink link : [
        SELECT
          LinkedEntityId,
          ContentDocument.Title,
          ContentDocument.FileExtension,
          ContentDocument.CreatedDate
        FROM ContentDocumentLink
        WHERE LinkedEntityId IN :caseIds
        WITH USER_MODE
        ORDER BY ContentDocument.CreatedDate ASC
      ]) {
        byCase.get(link.LinkedEntityId)
          .add(
            PromptFormat.quoted(
                EvidenceChecklist.fileName(
                  link.ContentDocument.Title,
                  link.ContentDocument.FileExtension
                ),
                MAX_TITLE_LENGTH
              ) +
              ', added ' +
              PromptFormat.day(link.ContentDocument.CreatedDate.date())
          );
      }
    } catch (QueryException notReadable) {
      for (PromptSection section : byCase.values()) {
        section.markUnavailable();
      }
    }
    return byCase;
  }

  private static Map<Id, PromptSection> comments(Set<Id> caseIds) {
    Map<Id, PromptSection> byCase = new Map<Id, PromptSection>();
    for (Id caseId : caseIds) {
      byCase.put(
        caseId,
        new PromptSection(
          'Case comments (newest first, up to ' + MAX_COMMENTS + '):',
          'none.',
          MAX_COMMENTS
        )
      );
    }
    try {
      for (CaseComment comment : [
        SELECT ParentId, CommentBody, CreatedDate
        FROM CaseComment
        WHERE ParentId IN :caseIds
        WITH USER_MODE
        ORDER BY CreatedDate DESC
      ]) {
        byCase.get(comment.ParentId)
          .add(
            PromptFormat.day(comment.CreatedDate.date()) +
              ': ' +
              PromptFormat.quoted(comment.CommentBody, MAX_COMMENT_LENGTH)
          );
      }
    } catch (QueryException notReadable) {
      for (PromptSection section : byCase.values()) {
        section.markUnavailable();
      }
    }
    return byCase;
  }
}
