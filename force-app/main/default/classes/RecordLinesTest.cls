/**
 * ST-08, ST-09, S-20. Proves each kind of record reads the same way wherever the rep assistant
 * writes it: a judged promise shows what was received, a payment shows its method only when the
 * query read it, a missing statement says so, and notes and terms are fenced as quoted text.
 * The records are built in memory, so the figures are exact and no automation runs.
 */
@IsTest
private class RecordLinesTest {
  @IsTest
  static void aJudgedPromiseShowsWhatWasReceived() {
    String brokenLine = RecordLines.promise(judgedPromise('Broken', 100));
    String keptLine = RecordLines.promise(judgedPromise('Kept', null));

    Assert.isTrue(
      brokenLine.endsWith(
        ': $250.00 promised for Aug 15, 2026, status Broken, $100.00 received'
      ),
      brokenLine
    );
    Assert.isTrue(
      keptLine.endsWith(': $250.00 promised for Aug 15, 2026, status Kept'),
      'Nothing about money received when none is recorded: ' + keptLine
    );
  }

  @IsTest
  static void aPaymentShowsItsMethodOnlyWhenTheQueryReadIt() {
    Payment__c withMethod = new Payment__c(
      Payment_Date__c = Date.newInstance(2026, 9, 30),
      Amount__c = 171.31,
      Method__c = 'ACH'
    );
    Payment__c withoutMethod = new Payment__c(
      Payment_Date__c = Date.newInstance(2026, 9, 30),
      Amount__c = 171.31
    );

    Assert.areEqual(
      'Sep 30, 2026: $171.31, by ACH',
      RecordLines.payment(withMethod),
      'With the method'
    );
    Assert.areEqual(
      'Sep 30, 2026: $171.31',
      RecordLines.payment(withoutMethod),
      'Without it'
    );
  }

  @IsTest
  static void aMissingStatementSaysSo() {
    Assert.areEqual(
      'None recorded.',
      RecordLines.disputedStatement(null),
      'No statement'
    );
  }

  @IsTest
  static void attemptsAndCommitmentsFenceWhatPeopleTyped() {
    Commitment__c delayedStart = new Commitment__c(
      Type__c = 'Delayed Billing Start',
      Months_Covered__c = 1,
      Status__c = 'Recorded',
      Terms__c = 'Billing starts one month after activation.'
    );

    Assert.isTrue(
      RecordLines.contactAttempt(attempt('Call back at 502-555-0100'))
        .endsWith(
          ': Left Voicemail. Notes: <quoted>Call back at ' +
            SensitiveText.PHONE_PLACEHOLDER +
            '</quoted>'
        ),
      'The notes are quoted, without the phone number'
    );
    Assert.isTrue(
      RecordLines.contactAttempt(attempt(null)).endsWith(': Left Voicemail.'),
      'No notes, no quote'
    );
    Assert.areEqual(
      'Delayed Billing Start, value none (not a dollar amount), 1 month covered, status Recorded. Terms: <quoted>Billing starts one month after activation.</quoted>',
      RecordLines.commitment(delayedStart, null),
      'No dollar value, one month, and the terms quoted'
    );
  }

  // A promise judged after its date. CreatedDate can only be set this way.
  private static Promise_to_Pay__c judgedPromise(
    String status,
    Decimal received
  ) {
    Promise_to_Pay__c promise = (Promise_to_Pay__c) JSON.deserialize(
      '{"attributes":{"type":"Promise_to_Pay__c"},' +
      '"CreatedDate":"2026-08-01T15:00:00.000+0000"}',
      Promise_to_Pay__c.class
    );
    promise.Promise_Amount__c = 250;
    promise.Promise_Date__c = Date.newInstance(2026, 8, 15);
    promise.Status__c = status;
    promise.Amount_Received__c = received;
    return promise;
  }

  // A contact attempt logged on Oct 14. CreatedDate can only be set this way.
  private static Task attempt(String notes) {
    Task logged = (Task) JSON.deserialize(
      '{"attributes":{"type":"Task"},"CreatedDate":"2026-10-14T15:00:00.000+0000"}',
      Task.class
    );
    logged.Contact_Outcome__c = 'Left Voicemail';
    logged.Description = notes;
    return logged;
  }
}
