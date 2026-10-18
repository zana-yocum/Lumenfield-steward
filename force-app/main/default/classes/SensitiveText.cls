/**
 * ST-05, ST-11, S-06. Removes card numbers from free text before Steward stores it, so a number
 * a customer types into the chat never lands in a log record or a dispute description.
 */
public with sharing class SensitiveText {
  /** What a removed card number is replaced with. */
  public static final String CARD_NUMBER_PLACEHOLDER = '[card number removed]';

  // 13 to 19 digits, optionally split by single spaces or hyphens: the shape of a card number.
  private static final Pattern CARD_NUMBER = Pattern.compile(
    '(?<!\\d)\\d(?:[ -]?\\d){12,18}(?!\\d)'
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
}
