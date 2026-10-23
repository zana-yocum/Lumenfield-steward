/**
 * ST-08, S-20. The data behind the Steward_Account_Briefing prompt template: one household's
 * balances, unpaid statements, last payments, promises, open disputes with their next SLA
 * milestone, commitments from signing and recent contact attempts, written as labelled lines the
 * model copies. Prompt Builder runs it as the person who clicked Briefing, and every query is in
 * user mode, so a briefing holds only what that person can see. A section the person can't read
 * says so instead of failing the whole briefing. The payment method is added only for someone who
 * can read it (PS_Payment_Detail), and nothing that identifies a person is sent: no names, email
 * addresses, phone numbers or street addresses.
 */
// Prompt Builder matches these names: the template's input is Household, and the text it merges
// is Prompt.
@SuppressWarnings('PMD.FieldNamingConventions')
public with sharing class AccountBriefingPrompt {
  /** What the template receives for a household the person can't see. */
  public static final String NO_ACCESS = 'NO ACCESS: this household isn\'t available to the person asking.';
  /** What a section the person can't read says. */
  public static final String NOT_AVAILABLE = PromptSection.NOT_AVAILABLE;
  /** Added when there's nothing on record for collections to talk about. */
  public static final String NO_HISTORY = HouseholdBriefing.NO_HISTORY;

  private static final String DISPUTE_RECORD_TYPE = 'Billing_Dispute';

  /**
   * Set by tests to stand in for a user without PS_Payment_Detail. Null in normal use, when the
   * running user's own field access decides.
   */
  @TestVisible
  private static Boolean paymentMethodReadableOverride;

  /** The template's input. */
  public class Request {
    @InvocableVariable(label='Household' required=true)
    public Account Household;
  }

  /** The text Prompt Builder merges into the template. */
  public class Response {
    @InvocableVariable(label='Prompt')
    public String Prompt;
  }

  /**
   * Prompt Builder's entry point for Steward_Account_Briefing.
   * @param requests one per generation, each with the household from the page
   * @return the briefing data for each request, in the same order
   */
  @InvocableMethod(
    label='Steward account briefing data'
    description='The household facts behind the Steward_Account_Briefing prompt template, read with the running user\'s access.'
  )
  public static List<Response> getPrompt(List<Request> requests) {
    List<Id> accountIds = new List<Id>();
    for (Request request : requests) {
      accountIds.add(request?.Household?.Id);
    }
    Map<Id, String> texts = build(new Set<Id>(accountIds));
    List<Response> responses = new List<Response>();
    for (String text : PromptFormat.inOrder(accountIds, texts, NO_ACCESS)) {
      Response response = new Response();
      response.Prompt = text;
      responses.add(response);
    }
    return responses;
  }

  /**
   * The briefing data for each household the running user can see, with the same queries
   * however many there are.
   * @param accountIds the households
   * @return the text for each visible household; households the user can't see are left out
   */
  public static Map<Id, String> build(Set<Id> accountIds) {
    Map<Id, HouseholdBriefing> briefings = new Map<Id, HouseholdBriefing>();
    for (Id accountId : HouseholdScope.visibleHouseholds(accountIds)) {
      briefings.put(accountId, new HouseholdBriefing());
    }
    if (!briefings.isEmpty()) {
      addFacts(briefings);
      addStatements(briefings);
      addPayments(briefings);
      addPromises(briefings);
      addDisputes(briefings);
      addCommitments(briefings);
      addContactAttempts(briefings);
    }
    Map<Id, String> texts = new Map<Id, String>();
    for (Id accountId : briefings.keySet()) {
      texts.put(accountId, briefings.get(accountId).toText());
    }
    return texts;
  }

  private static void addFacts(Map<Id, HouseholdBriefing> briefings) {
    for (Account household : [
      SELECT
        Id,
        Account_Status__c,
        Current_Balance__c,
        Past_Due_Balance__c,
        Days_Past_Due__c,
        DPD_Bucket__c,
        Oldest_Past_Due_Date__c,
        Do_Not_Contact__c,
        Collection_Hold_Until__c,
        Broken_Promises_90d__c
      FROM Account
      WHERE Id IN :briefings.keySet()
      WITH USER_MODE
    ]) {
      HouseholdBriefing briefing = briefings.get(household.Id);
      briefing.pastDueBalance = household.Past_Due_Balance__c;
      briefing.facts.addAll(
        new List<String>{
          'Account status: ' +
          PromptFormat.orNotRecorded(household.Account_Status__c),
          'Current balance: ' +
          PromptFormat.money(household.Current_Balance__c),
          'Past-due balance: ' +
          PromptFormat.money(household.Past_Due_Balance__c),
          'Days past due: ' +
          PromptFormat.wholeNumber(household.Days_Past_Due__c) +
          ' (' +
          PromptFormat.orNotRecorded(household.DPD_Bucket__c) +
          ' bucket)',
          'Oldest unpaid due date: ' +
          PromptFormat.dayOr(household.Oldest_Past_Due_Date__c, 'none'),
          'Do Not Contact: ' + PromptFormat.yesNo(household.Do_Not_Contact__c),
          'Collection hold until: ' +
          PromptFormat.dayOr(household.Collection_Hold_Until__c, 'none'),
          'Broken promises in the last 90 days: ' +
          PromptFormat.wholeNumber(household.Broken_Promises_90d__c)
        }
      );
    }
  }

  private static void addStatements(Map<Id, HouseholdBriefing> briefings) {
    try {
      for (Billing_Statement__c statement : [
        SELECT Id, Name, Account__c, Due_Date__c, Balance__c, Status__c
        FROM Billing_Statement__c
        WHERE Account__c IN :briefings.keySet()
        WITH USER_MODE
        ORDER BY Due_Date__c ASC, Name ASC
      ]) {
        if ((statement.Balance__c ?? 0) > 0) {
          briefings.get(statement.Account__c)
            .statements.add(RecordLines.unpaidStatement(statement));
        }
      }
    } catch (QueryException notReadable) {
      markUnavailable(briefings, 'statements');
    }
  }

  // The method is in the query only for someone who can read it, so RecordLines.payment never
  // sees it for anyone else.
  private static void addPayments(Map<Id, HouseholdBriefing> briefings) {
    try {
      List<Payment__c> payments = paymentMethodReadable()
        ? [
            SELECT
              Id,
              Payment_Date__c,
              Amount__c,
              Method__c,
              Billing_Statement__r.Account__c
            FROM Payment__c
            WHERE Billing_Statement__r.Account__c IN :briefings.keySet()
            WITH USER_MODE
            ORDER BY Payment_Date__c DESC, Name DESC
          ]
        : [
            SELECT
              Id,
              Payment_Date__c,
              Amount__c,
              Billing_Statement__r.Account__c
            FROM Payment__c
            WHERE Billing_Statement__r.Account__c IN :briefings.keySet()
            WITH USER_MODE
            ORDER BY Payment_Date__c DESC, Name DESC
          ];
      for (Payment__c payment : payments) {
        briefings.get(payment.Billing_Statement__r.Account__c)
          .payments.add(RecordLines.payment(payment));
      }
    } catch (QueryException notReadable) {
      markUnavailable(briefings, 'payments');
    }
  }

  private static void addPromises(Map<Id, HouseholdBriefing> briefings) {
    Date recentSince = Date.today()
      .addDays(-HouseholdBriefing.RECENT_PROMISE_DAYS);
    try {
      for (Promise_to_Pay__c promise : [
        SELECT
          Id,
          Account__c,
          CreatedDate,
          Promise_Amount__c,
          Promise_Date__c,
          Status__c,
          Amount_Received__c,
          Grace_Ends__c
        FROM Promise_to_Pay__c
        WHERE
          Account__c IN :briefings.keySet()
          AND (Status__c IN :RecordLines.OPEN_PROMISE_STATUSES
          OR Promise_Date__c >= :recentSince)
        WITH USER_MODE
        ORDER BY CreatedDate DESC
      ]) {
        briefings.get(promise.Account__c)
          .promises.add(RecordLines.promise(promise));
      }
    } catch (QueryException notReadable) {
      markUnavailable(briefings, 'promises');
    }
  }

  // Found through the disputed statement's household: collections personas can't read
  // Case.AccountId, and the statement's account is the same household.
  private static void addDisputes(Map<Id, HouseholdBriefing> briefings) {
    List<Case> disputes;
    try {
      disputes = [
        SELECT
          Id,
          CaseNumber,
          Status,
          Dispute_Reason__c,
          CreatedDate,
          Disputed_Statement__r.Name,
          Disputed_Statement__r.Account__c
        FROM Case
        WHERE
          Disputed_Statement__r.Account__c IN :briefings.keySet()
          AND RecordType.DeveloperName = :DISPUTE_RECORD_TYPE
          AND IsClosed = FALSE
        WITH USER_MODE
        ORDER BY CreatedDate ASC
      ];
    } catch (QueryException notReadable) {
      markUnavailable(briefings, 'disputes');
      return;
    }
    Map<Id, String> milestones = SlaMilestones.nextFor(
      new Map<Id, Case>(disputes).keySet()
    );
    for (Case dispute : disputes) {
      briefings.get(dispute.Disputed_Statement__r.Account__c)
        .disputes.add(RecordLines.dispute(dispute, milestones.get(dispute.Id)));
    }
  }

  private static void addCommitments(Map<Id, HouseholdBriefing> briefings) {
    try {
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
        WHERE Account__c IN :briefings.keySet()
        WITH USER_MODE
        ORDER BY CreatedDate ASC
      ]) {
        briefings.get(commitment.Account__c)
          .commitments.add(RecordLines.commitment(commitment, null));
      }
    } catch (QueryException notReadable) {
      markUnavailable(briefings, 'commitments');
    }
  }

  private static void addContactAttempts(Map<Id, HouseholdBriefing> briefings) {
    try {
      for (Task attempt : [
        SELECT Id, WhatId, CreatedDate, Contact_Outcome__c, Description
        FROM Task
        WHERE
          WhatId IN :briefings.keySet()
          AND Contact_Outcome__c != NULL
          AND CreatedDate = LAST_N_DAYS:30
        WITH USER_MODE
        ORDER BY CreatedDate DESC
      ]) {
        briefings.get(attempt.WhatId)
          .attempts.add(RecordLines.contactAttempt(attempt));
      }
    } catch (QueryException notReadable) {
      markUnavailable(briefings, 'attempts');
    }
  }

  private static Boolean paymentMethodReadable() {
    return paymentMethodReadableOverride ??
      Schema.SObjectType.Payment__c.fields.Method__c.isAccessible();
  }

  private static void markUnavailable(
    Map<Id, HouseholdBriefing> briefings,
    String sectionName
  ) {
    for (HouseholdBriefing briefing : briefings.values()) {
      briefing.section(sectionName).markUnavailable();
    }
  }
}
