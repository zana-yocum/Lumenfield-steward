/**
 * ST-05, S-06. Proves card numbers are removed in every common format, and that ordinary numbers
 * a customer mentions (phone numbers, amounts, dates, statement numbers) are left alone.
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
}
