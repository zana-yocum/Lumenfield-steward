/**
 * ST-05, ST-11, ST-17, S-06. Removes card numbers from free text before Steward stores it, so a
 * number a customer types into the chat never lands in a log record or a dispute description.
 * Text on its way to a model loses email addresses and phone numbers as well (S-20).
 */
public with sharing class SensitiveText {
  /** What a removed card number is replaced with. */
  public static final String CARD_NUMBER_PLACEHOLDER = '[card number removed]';
  /** What a removed email address is replaced with. */
  public static final String EMAIL_PLACEHOLDER = '[email address removed]';
  /** What a removed phone number is replaced with. */
  public static final String PHONE_PLACEHOLDER = '[phone number removed]';

  // 13 to 19 digits, optionally split by single spaces or hyphens: the shape of a card number.
  private static final Pattern CARD_NUMBER = Pattern.compile(
    '(?<!\\d)\\d(?:[ -]?\\d){12,18}(?!\\d)'
  );

  private static final Pattern EMAIL_ADDRESS = Pattern.compile(
    '[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}'
  );

  // Ten digits, as North American numbers are written: an optional +1, the area code with or
  // without brackets, then three and four digits, split by spaces, dots or hyphens or not at all.
  // Amounts, dates, statement numbers and eight-digit case numbers don't have this shape.
  private static final Pattern PHONE_NUMBER = Pattern.compile(
    '(?<![\\d$])(?:\\+?1[ .-]?)?(?:\\(\\d{3}\\) ?|\\d{3}[ .-]?)\\d{3}[ .-]?\\d{4}(?!\\d)'
  );

  /**
   * The text with anything shaped like a card number replaced.
   * @param text free text, such as a customer's description
   * @return the text with card numbers removed; blank text comes back unchanged
   */
  public static String redact(String text) {
    if (String.isBlank(text)) {
      return text;
    }
    return CARD_NUMBER.matcher(text).replaceAll(CARD_NUMBER_PLACEHOLDER);
  }

  /**
   * The text with card numbers, email addresses and phone numbers replaced, for text a person
   * typed that's about to reach a model (S-20). Card numbers go first, so part of one is never
   * mistaken for a phone number.
   * @param text free text, such as a dispute description or a rep's notes
   * @return the text with those details removed; blank text comes back unchanged
   */
  public static String redactForPrompt(String text) {
    if (String.isBlank(text)) {
      return text;
    }
    String result = redact(text);
    result = EMAIL_ADDRESS.matcher(result).replaceAll(EMAIL_PLACEHOLDER);
    return PHONE_NUMBER.matcher(result).replaceAll(PHONE_PLACEHOLDER);
  }
}
