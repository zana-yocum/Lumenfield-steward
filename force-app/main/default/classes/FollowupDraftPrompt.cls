/**
 * ST-10, S-20. The data behind the Steward_Followup_Draft prompt template: the outcome of the
 * contact attempt the person logged on the household today, the promise they recorded today if
 * there is one (amount, date and status, straight from the Promise to Pay record), the past-due
 * balance and Do Not Contact. Read in user mode, as the person asking. The model never sees the
 * customer's name or address: the controller adds the greeting and the recipient afterwards. The
 * rep's notes from the call stay out too, because the draft goes to the customer.
 */
// Prompt Builder matches these names: the template's input is Household, and the text it merges
// is Prompt.
@SuppressWarnings('PMD.FieldNamingConventions')
public with sharing class FollowupDraftPrompt {
  /** What the template receives for a household the person can't see. */
  public static final String NO_ACCESS = 'NO ACCESS: this household isn\'t available to the person asking.';
  /** The outcome that comes with a promise to pay. */
  public static final String PROMISE_MADE = 'Promise Made';

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
   * Prompt Builder's entry point for Steward_Followup_Draft.
   * @param requests one per generation, each with the household from the page
   * @return the follow-up data for each request, in the same order
   */
  @InvocableMethod(
    label='Steward follow-up draft data'
    description='The call outcome and promise behind the Steward_Followup_Draft prompt template, read with the running user\'s access.'
    CapabilityType='FlexTemplate://Steward_Followup_Draft'
  )
  public static List<Response> getPrompt(List<Request> requests) {
    List<Id> accountIds = new List<Id>();
    for (Request request : requests) {
      accountIds.add(request?.Household?.Id);
    }
    List<Response> responses = new List<Response>();
    for (
      String text : PromptFormat.inOrder(
        accountIds,
        build(new Set<Id>(accountIds)),
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
   * The follow-up data for each household the running user can see.
   * @param accountIds the households
   * @return the text for each visible household; households the user can't see are left out
   */
  public static Map<Id, String> build(Set<Id> accountIds) {
    Map<Id, String> texts = new Map<Id, String>();
    Set<Id> visible = HouseholdScope.visibleHouseholds(accountIds);
    if (visible.isEmpty()) {
      return texts;
    }
    Map<Id, Task> attempts = attemptsToday(visible);
    Map<Id, Promise_to_Pay__c> promises = promisesToday(visible);
    for (Account household : [
      SELECT Id, Past_Due_Balance__c, Do_Not_Contact__c
      FROM Account
      WHERE Id IN :visible
      WITH USER_MODE
    ]) {
      Task attempt = attempts.get(household.Id);
      List<String> text = new List<String>{
        'Today: ' + PromptFormat.day(Date.today()),
        'Outcome of today\'s contact attempt: ' +
        (attempt == null ? 'none logged' : attempt.Contact_Outcome__c)
      };
      if (attempt?.Contact_Outcome__c == PROMISE_MADE) {
        text.add(
          'Promise made today: ' + describePromise(promises.get(household.Id))
        );
      }
      text.add(
        'Past-due balance: ' + PromptFormat.money(household.Past_Due_Balance__c)
      );
      text.add(
        'Do Not Contact: ' + PromptFormat.yesNo(household.Do_Not_Contact__c)
      );
      texts.put(household.Id, String.join(text, '\n'));
    }
    return texts;
  }

  /**
   * The contact attempt with an outcome that the running user logged on the household today.
   * The draft is grounded in this record, so without one there's no draft.
   * @param accountId the household
   * @return the newest such attempt, or null when there isn't one
   */
  public static Task latestAttemptToday(Id accountId) {
    return attemptsToday(new Set<Id>{ accountId }).get(accountId);
  }

  // Someone who can't read contact outcomes has no attempt to ground a draft in.
  private static Map<Id, Task> attemptsToday(Set<Id> accountIds) {
    Map<Id, Task> newest = new Map<Id, Task>();
    try {
      for (Task attempt : [
        SELECT Id, WhatId, Contact_Outcome__c, CreatedDate
        FROM Task
        WHERE
          WhatId IN :accountIds
          AND CreatedById = :UserInfo.getUserId()
          AND CreatedDate = TODAY
          AND Contact_Outcome__c != NULL
        WITH USER_MODE
        ORDER BY CreatedDate DESC
      ]) {
        if (!newest.containsKey(attempt.WhatId)) {
          newest.put(attempt.WhatId, attempt);
        }
      }
    } catch (QueryException notReadable) {
      newest.clear();
    }
    return newest;
  }

  // Accord's Log Contact Attempt flow saves the promise in the same screen flow, so the newest
  // promise the same person recorded today is the one the call produced.
  private static Map<Id, Promise_to_Pay__c> promisesToday(Set<Id> accountIds) {
    Map<Id, Promise_to_Pay__c> newest = new Map<Id, Promise_to_Pay__c>();
    try {
      for (Promise_to_Pay__c promise : [
        SELECT Id, Account__c, Promise_Amount__c, Promise_Date__c, Status__c
        FROM Promise_to_Pay__c
        WHERE
          Account__c IN :accountIds
          AND CreatedById = :UserInfo.getUserId()
          AND CreatedDate = TODAY
        WITH USER_MODE
        ORDER BY CreatedDate DESC
      ]) {
        if (!newest.containsKey(promise.Account__c)) {
          newest.put(promise.Account__c, promise);
        }
      }
    } catch (QueryException notReadable) {
      newest.clear();
    }
    return newest;
  }

  private static String describePromise(Promise_to_Pay__c promise) {
    if (promise == null) {
      return 'none found.';
    }
    return PromptFormat.money(promise.Promise_Amount__c) +
      ' by ' +
      PromptFormat.day(promise.Promise_Date__c) +
      ', status ' +
      PromptFormat.orNotRecorded(promise.Status__c);
  }
}
