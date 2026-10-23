/**
 * ST-05, ST-17, S-06, S-20. Proves card numbers are removed in every common format, and that
 * ordinary numbers a customer mentions (phone numbers, amounts, dates, statement numbers) are left
 * alone when Steward stores text. Text on its way to a model also loses email addresses and phone
 * numbers, and still keeps amounts, dates and record numbers.
 */
@IsTest
private class SensitiveTextTest {
  @IsTest
  static void removesCardNumbersInEveryCommonFormat() {
    List<String> cards = new List<String>{
      '4111111111111111',
      '4111 1111 1111 1111',
      '4111-1111-1111-1111',
      '378282246310005',
      '6011000990139424123'
    };
    for (String card : cards) {
      String redacted = SensitiveText.redact('My card is ' + card + ', thanks');
      Assert.areEqual(
        'My card is ' + SensitiveText.CARD_NUMBER_PLACEHOLDER + ', thanks',
        redacted,
        'Removed: ' + card
      );
    }
  }

  @IsTest
  static void leavesOrdinaryNumbersAlone() {
    String text = 'Call 555-123-4567 about $190.00 due 2026-10-28 on BS-000123, account 12345678.';

    Assert.areEqual(
      text,
      SensitiveText.redact(text),
      'Phone, amount, date and statement numbers stay'
    );
  }

  @IsTest
  static void blankTextComesBackUnchanged() {
    Assert.isNull(SensitiveText.redact(null), 'Null stays null');
    Assert.areEqual('', SensitiveText.redact(''), 'Empty stays empty');
    Assert.areEqual('   ', SensitiveText.redact('   '), 'Spaces stay spaces');
  }

  @IsTest
  static void promptTextLosesEmailAddressesAndPhoneNumbers() {
    List<String> phones = new List<String>{
      '502-555-0100',
      '(502) 555-0100',
      '502.555.0100',
      '5025550100',
      '+1 502 555 0100'
    };
    for (String phone : phones) {
      Assert.areEqual(
        'Call ' + SensitiveText.PHONE_PLACEHOLDER + ' after 5',
        SensitiveText.redactForPrompt('Call ' + phone + ' after 5'),
        'Removed: ' + phone
      );
    }
    Assert.areEqual(
      'Write to ' + SensitiveText.EMAIL_PLACEHOLDER + ', please',
      SensitiveText.redactForPrompt('Write to pat.lee@example.com, please'),
      'Email address removed'
    );
    Assert.areEqual(
      'Card ' + SensitiveText.CARD_NUMBER_PLACEHOLDER + ' declined',
      SensitiveText.redactForPrompt('Card 4111 1111 1111 1111 declined'),
      'A card number is still a card number, not a phone number'
    );
  }

  @IsTest
  static void promptTextKeepsFiguresAndRecordNumbers() {
    String text = 'Paid $1,234.50 on 2026-10-23 (10/23/2026) for STMT-00854, case 00001053, account 12345678.';

    Assert.areEqual(
      text,
      SensitiveText.redactForPrompt(text),
      'Amounts, dates, statement, case and account numbers stay'
    );
    Assert.isNull(SensitiveText.redactForPrompt(null), 'Null stays null');
    Assert.areEqual(
      '  ',
      SensitiveText.redactForPrompt('  '),
      'Spaces stay spaces'
    );
  }
}
