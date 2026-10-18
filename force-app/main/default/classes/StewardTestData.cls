/**
 * NFR-03. Builds the invented households Steward's tests run against: a Residential Agreement
 * account, its primary contact, an agreement, and whatever statements, payments, credits,
 * promises, entitlements and commitments a test needs. The contact is inserted before anything
 * else on the account: Accord's flow makes it the primary contact, and Accord's validation rule
 * won't let the account change without one. No test reads org data (no SeeAllData).
 */
// Factory methods take the record's own fields as parameters; a builder would add code without
// making a test easier to read.
@SuppressWarnings('PMD.ExcessiveParameterList')
@IsTest
public class StewardTestData {
  public static final String ACCOUNT_CURRENT = 'Current';
  public static final String ACCOUNT_DELINQUENT = 'Delinquent';
  public static final String STATEMENT_OPEN = 'Open';
  public static final String STATEMENT_PAST_DUE = 'Past Due';
  public static final String STATEMENT_PAID = 'Paid';
  public static final Decimal MONTHLY_PAYMENT = 120.00;
  /** 2.90% a year: $120.00 becomes $123.48 at the first anniversary. */
  public static final Decimal ESCALATOR_RATE_PCT = 2.90;
  public static final String DISPUTE_RECORD_TYPE = 'Billing_Dispute';

  private static Integer sequence = 0;
  // Keeps names and emails unique when a test method adds households to its @TestSetup ones.
  private static final String RUN = EncodingUtil.convertToHex(
      Crypto.generateAesKey(128)
    )
    .left(6)
    .toUpperCase();

  /** An account with its primary contact and agreement. */
  public class Household {
    public Account account;
    public Contact primaryContact;
    public ServiceContract agreement;
  }

  /**
   * Inserts households: a Residential Agreement account, a primary contact and an agreement each.
   * @param count how many
   * @param accountStatus Account_Status__c for all of them
   * @return the households, in insert order
   */
  public static List<Household> createHouseholds(
    Integer count,
    String accountStatus
  ) {
    Id recordTypeId = householdRecordTypeId();
    List<String> suffixes = new List<String>();
    List<Account> accounts = new List<Account>();
    for (Integer i = 0; i < count; i++) {
      String suffix = nextSuffix();
      suffixes.add(suffix);
      accounts.add(
        new Account(
          Name = 'Steward Test Household ' + suffix,
          RecordTypeId = recordTypeId,
          Account_Status__c = accountStatus,
          Broken_Promises_90d__c = 0
        )
      );
    }
    insert accounts;

    List<Contact> contacts = new List<Contact>();
    for (Integer i = 0; i < count; i++) {
      contacts.add(
        new Contact(
          FirstName = 'Test',
          LastName = 'Customer ' + suffixes[i],
          Email = 'steward.customer.' + suffixes[i] + '@example.com',
          AccountId = accounts[i].Id,
          Role_on_Agreement__c = 'Primary'
        )
      );
    }
    // Accord's Contact_AfterSave_StampPrimaryContact makes each one its account's primary contact.
    insert contacts;

    Date firstDue = firstDueDate();
    List<ServiceContract> agreements = new List<ServiceContract>();
    for (Integer i = 0; i < count; i++) {
      agreements.add(
        new ServiceContract(
          Name = 'Steward Test Agreement ' + suffixes[i],
          AccountId = accounts[i].Id,
          StartDate = firstDue.addMonths(-1),
          First_Due_Date__c = firstDue,
          Monthly_Payment__c = MONTHLY_PAYMENT,
          Escalator_Rate__c = ESCALATOR_RATE_PCT
        )
      );
    }
    insert agreements;

    List<Household> households = new List<Household>();
    for (Integer i = 0; i < count; i++) {
      Household household = new Household();
      household.account = accounts[i];
      household.primaryContact = contacts[i];
      household.agreement = agreements[i];
      households.add(household);
    }
    return households;
  }

  /**
   * One Delinquent household.
   * @return the household
   */
  public static Household createHousehold() {
    return createHouseholds(1, ACCOUNT_DELINQUENT)[0];
  }

  /**
   * The first payment due date on every test agreement.
   * @return the first of the month, 13 months ago; its first anniversary is the first of last month
   */
  public static Date firstDueDate() {
    return Date.today().toStartOfMonth().addMonths(-13);
  }

  /**
   * The first anniversary of every test agreement.
   * @return the first of last month
   */
  public static Date firstAnniversary() {
    return firstDueDate().addYears(1);
  }

  /**
   * The first of the month, some months back.
   * @param monthsAgo 0 for this month
   * @return that month's first day
   */
  public static Date monthStart(Integer monthsAgo) {
    return Date.today().toStartOfMonth().addMonths(-monthsAgo);
  }

  /**
   * A statement on the household's agreement, not inserted. The statement date is 20 days before
   * the due date.
   * @param household whose statement
   * @param dueDate the due date
   * @param amountDue the amount due
   * @param status Status__c
   * @return the statement
   */
  public static Billing_Statement__c statement(
    Household household,
    Date dueDate,
    Decimal amountDue,
    String status
  ) {
    return new Billing_Statement__c(
      Account__c = household.account.Id,
      Service_Contract__c = household.agreement.Id,
      Statement_Date__c = dueDate.addDays(-20),
      Due_Date__c = dueDate,
      Amount_Due__c = amountDue,
      Status__c = status
    );
  }

  /**
   * A lease payment, not inserted.
   * @param statement the statement it pays
   * @param amount the amount
   * @param paidOn the payment date, today or earlier
   * @return the payment
   */
  public static Payment__c payment(
    Billing_Statement__c statement,
    Decimal amount,
    Date paidOn
  ) {
    return new Payment__c(
      Billing_Statement__c = statement.Id,
      Amount__c = amount,
      Payment_Date__c = paidOn,
      Method__c = 'ACH',
      External_Reference__c = 'STEWARD-TEST-' + nextSuffix()
    );
  }

  /**
   * A credit adjustment on a statement, not inserted. Posted credits get today's posted date;
   * rejected ones get a reason, which Accord's validation rule requires.
   * @param statement the statement it credits
   * @param amount the amount
   * @param type Type__c
   * @param status Status__c
   * @return the adjustment
   */
  public static Adjustment__c credit(
    Billing_Statement__c statement,
    Decimal amount,
    String type,
    String status
  ) {
    return new Adjustment__c(
      Name = type + ' ' + nextSuffix(),
      Account__c = statement.Account__c,
      Billing_Statement__c = statement.Id,
      Amount__c = amount,
      Type__c = type,
      Status__c = status,
      Posted_Date__c = status == 'Posted' ? Date.today() : null,
      Rejection_Reason__c = status == 'Rejected'
        ? 'Not supported by the records'
        : null
    );
  }

  /**
   * A promise to pay, not inserted.
   * @param household whose promise
   * @param promiseDate the promise date
   * @param amount the amount
   * @param status Status__c
   * @return the promise
   */
  public static Promise_to_Pay__c promise(
    Household household,
    Date promiseDate,
    Decimal amount,
    String status
  ) {
    return new Promise_to_Pay__c(
      Account__c = household.account.Id,
      Promise_Date__c = promiseDate,
      Promise_Amount__c = amount,
      Status__c = status
    );
  }

  /**
   * An open opportunity, not inserted. Open, so Accord's Closed Won flow and rule stay out of it.
   * @param household whose deal
   * @return the opportunity
   */
  public static Opportunity deal(Household household) {
    return new Opportunity(
      Name = 'Steward Test Deal ' + nextSuffix(),
      AccountId = household.account.Id,
      StageName = 'Negotiation/Review',
      CloseDate = Date.today().addDays(30)
    );
  }

  /**
   * A commitment on a deal, not inserted. Accord's flow stamps its Account__c on save.
   * @param deal the opportunity it belongs to
   * @param type Type__c
   * @param value Value__c
   * @param monthsCovered Months_Covered__c, or null
   * @param terms Terms__c
   * @param status Status__c
   * @return the commitment
   */
  public static Commitment__c commitment(
    Opportunity deal,
    String type,
    Decimal value,
    Integer monthsCovered,
    String terms,
    String status
  ) {
    return new Commitment__c(
      Opportunity__c = deal.Id,
      Type__c = type,
      Value__c = value,
      Months_Covered__c = monthsCovered,
      Terms__c = terms,
      Status__c = status,
      Recorded_By__c = UserInfo.getUserId()
    );
  }

  /**
   * An active entitlement for the household, not inserted.
   * @param household whose entitlement
   * @return the entitlement
   */
  public static Entitlement entitlement(Household household) {
    return new Entitlement(
      Name = 'Steward Test SLA ' + nextSuffix(),
      AccountId = household.account.Id,
      StartDate = Date.today().addDays(-30),
      EndDate = Date.today().addDays(335)
    );
  }

  /**
   * Inserts a Billing Dispute case directly, the way a rep would, for tests that need one to exist.
   * @param household whose dispute
   * @param statement the disputed statement
   * @param reason a Dispute_Reason__c value
   * @return the inserted case
   */
  public static Case insertDispute(
    Household household,
    Billing_Statement__c statement,
    String reason
  ) {
    Case dispute = new Case(
      RecordTypeId = Schema.SObjectType.Case.getRecordTypeInfosByDeveloperName()
        .get(DISPUTE_RECORD_TYPE)
        .getRecordTypeId(),
      AccountId = household.account.Id,
      ContactId = household.primaryContact.Id,
      Disputed_Statement__c = statement.Id,
      Dispute_Reason__c = reason,
      Origin = 'Phone',
      Subject = 'Billing dispute: ' + reason
    );
    insert dispute;
    return dispute;
  }

  /**
   * Inserts a user with no access to Accord's objects and no sharing on test accounts: the
   * Standard Platform User profile, which can read accounts only where sharing allows.
   * @return the inserted user
   */
  public static User createUserWithoutAccess() {
    Profile platformProfile = [
      SELECT Id
      FROM Profile
      WHERE Name = 'Standard Platform User'
      LIMIT 1
    ];
    String suffix = nextSuffix();
    User outsider = new User(
      Alias = 'stwtest',
      Email = 'steward.outsider.' + suffix + '@example.com',
      EmailEncodingKey = 'UTF-8',
      FirstName = 'Steward',
      LastName = 'Outsider',
      LanguageLocaleKey = 'en_US',
      LocaleSidKey = 'en_US',
      ProfileId = platformProfile.Id,
      TimeZoneSidKey = 'America/New_York',
      Username = 'steward.outsider.' +
        suffix +
        '.' +
        Math.abs(Crypto.getRandomInteger()) +
        '@example.com'
    );
    // A separate context, so creating a user doesn't collide with the test's other inserts.
    System.runAs(new User(Id = UserInfo.getUserId())) {
      insert outsider;
    }
    return outsider;
  }

  /**
   * Shares an account with a user, read only.
   * @param accountId the account
   * @param userId the user
   */
  public static void shareRead(Id accountId, Id userId) {
    insert new AccountShare(
      AccountId = accountId,
      UserOrGroupId = userId,
      AccountAccessLevel = 'Read',
      OpportunityAccessLevel = 'None',
      CaseAccessLevel = 'None'
    );
  }

  /**
   * A policy setting's number, read straight from Accord's record.
   * @param developerName the Policy_Setting__mdt record
   * @return its Number_Value__c
   */
  public static Decimal policyNumber(String developerName) {
    return Policy_Setting__mdt.getInstance(developerName).Number_Value__c;
  }

  private static Id householdRecordTypeId() {
    return Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName()
      .get('Residential_Agreement')
      .getRecordTypeId();
  }

  private static String nextSuffix() {
    sequence++;
    return String.valueOf(sequence).leftPad(4, '0') + '-' + RUN;
  }
}
