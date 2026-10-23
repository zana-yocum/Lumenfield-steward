/**
 * ST-08, ST-09, ST-10, ST-17, S-20. How the rep assistant writes record data for a prompt. Amounts,
 * dates and times come out in one fixed format whatever the user's locale, because the templates
 * tell the model to copy figures exactly as written. Anything a person typed (a description, a
 * note, a commitment's terms, a file name) is fenced as quoted text, after card numbers, email
 * addresses and phone numbers are taken out, so the model treats it as content and never as
 * instructions.
 */
public with sharing class PromptFormat {
  /** Opens a stretch of text a person typed. The templates name these tags. */
  public static final String QUOTE_OPEN = '<quoted>';
  /** Closes a stretch of text a person typed. */
  public static final String QUOTE_CLOSE = '</quoted>';
  /** What a missing value reads as. */
  public static final String NOT_RECORDED = 'not recorded';
  /** Added where quoted text was cut to length. */
  public static final String SHORTENED = ' [shortened]';

  private static final List<String> MONTHS = new List<String>{
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec'
  };

  /**
   * An amount in dollars and cents, such as $1,234.50 or -$12.00.
   * @param amount the amount
   * @return the formatted amount; "not recorded" for null
   */
  public static String money(Decimal amount) {
    if (amount == null) {
      return NOT_RECORDED;
    }
    Decimal rounded = amount.setScale(2, System.RoundingMode.HALF_UP);
    String digits = rounded.abs().toPlainString();
    String whole = digits.substringBefore('.');
    String cents = digits.substringAfter('.');
    String grouped = '';
    while (whole.length() > 3) {
      grouped = ',' + whole.right(3) + grouped;
      whole = whole.left(whole.length() - 3);
    }
    return (rounded < 0 ? '-' : '') + '$' + whole + grouped + '.' + cents;
  }

  /**
   * An amount, or the given words when there isn't one.
   * @param amount the amount
   * @param whenMissing what to write for null, such as "none"
   * @return the formatted amount or the words
   */
  public static String moneyOr(Decimal amount, String whenMissing) {
    return amount == null ? whenMissing : money(amount);
  }

  /**
   * A whole number, such as a count of days or months.
   * @param value the number
   * @return the number rounded to a whole one; "not recorded" for null
   */
  public static String wholeNumber(Decimal value) {
    return value == null
      ? NOT_RECORDED
      : String.valueOf(value.setScale(0, System.RoundingMode.HALF_UP));
  }

  /**
   * A date such as Oct 23, 2026.
   * @param value the date
   * @return the formatted date; "not recorded" for null
   */
  public static String day(Date value) {
    if (value == null) {
      return NOT_RECORDED;
    }
    return MONTHS[value.month() - 1] + ' ' + value.day() + ', ' + value.year();
  }

  /**
   * A date, or the given words when there isn't one.
   * @param value the date
   * @param whenMissing what to write for null, such as "none"
   * @return the formatted date or the words
   */
  public static String dayOr(Date value, String whenMissing) {
    return value == null ? whenMissing : day(value);
  }

  /**
   * A moment in the running user's time zone, such as Oct 23, 2026, 4:00 PM EDT.
   * @param value the date and time
   * @return the formatted moment; "not recorded" for null
   */
  public static String moment(Datetime value) {
    if (value == null) {
      return NOT_RECORDED;
    }
    return day(value.date()) + ', ' + value.format('h:mm a z');
  }

  /**
   * A moment, or the given words when there isn't one.
   * @param value the date and time
   * @param whenMissing what to write for null, such as "no"
   * @return the formatted moment or the words
   */
  public static String momentOr(Datetime value, String whenMissing) {
    return value == null ? whenMissing : moment(value);
  }

  /**
   * Yes or No.
   * @param value a checkbox
   * @return "Yes" only for true
   */
  // A formatter for a checkbox's value: the parameter is the value, not a switch in the logic.
  @SuppressWarnings('PMD.AvoidBooleanMethodParameters')
  public static String yesNo(Boolean value) {
    return value == true ? 'Yes' : 'No';
  }

  /**
   * A short value from a record, such as a status, or "not recorded".
   * @param value the value
   * @return the value, or "not recorded" when it's blank
   */
  public static String orNotRecorded(String value) {
    return String.isBlank(value) ? NOT_RECORDED : value;
  }

  /**
   * Text a person typed, fenced for a prompt. Card numbers, email addresses and phone numbers
   * are removed, whitespace is collapsed, angle brackets are swapped for lookalikes so the text
   * can't close the fence early, and anything over the limit is cut.
   * @param text the text
   * @param maxLength the most characters to keep
   * @return the fenced text; "(blank)" fenced when there's nothing
   */
  public static String quoted(String text, Integer maxLength) {
    String clean = SensitiveText.redactForPrompt(text);
    clean = String.isBlank(clean) ? '(blank)' : clean.normalizeSpace();
    clean = clean.replace('<', '‹').replace('>', '›');
    if (clean.length() > maxLength) {
      clean = clean.left(maxLength).trim() + SHORTENED;
    }
    return QUOTE_OPEN + clean + QUOTE_CLOSE;
  }

  /**
   * The text for each request, in the order Prompt Builder sent them. A request with no record,
   * or a record the person can't see, gets the fallback.
   * @param recordIds each request's record, in order; nulls allowed
   * @param texts the text for each record the person can see
   * @param fallback what everything else gets
   * @return one text per request, in order
   */
  public static List<String> inOrder(
    List<Id> recordIds,
    Map<Id, String> texts,
    String fallback
  ) {
    List<String> ordered = new List<String>();
    for (Id recordId : recordIds) {
      ordered.add(texts.containsKey(recordId) ? texts.get(recordId) : fallback);
    }
    return ordered;
  }
}
