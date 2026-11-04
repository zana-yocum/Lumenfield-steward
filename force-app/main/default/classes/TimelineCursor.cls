/**
 * ST-15. The timeline's place between pages: how many records of each kind it has already shown.
 * The next page asks each kind for the records after those, so nothing is repeated or skipped,
 * however the kinds interleave by date. A cursor is that count, as JSON, such as
 * {"STATEMENT":12,"PAYMENT":8}.
 */
public with sharing class TimelineCursor {
  /**
   * The counts in a cursor.
   * @param cursor the previous page's cursor; null or blank for the first page
   * @return counts by kind, empty for the first page, or null when the text isn't a cursor
   */
  public static Map<String, Integer> parse(String cursor) {
    Map<String, Integer> offsets = new Map<String, Integer>();
    if (String.isBlank(cursor)) {
      return offsets;
    }
    Object parsed;
    try {
      parsed = JSON.deserializeUntyped(cursor);
    } catch (JSONException notJson) {
      return null;
    }
    if (!(parsed instanceof Map<String, Object>)) {
      return null;
    }
    Map<String, Object> values = (Map<String, Object>) parsed;
    for (String kind : values.keySet()) {
      Object value = values.get(kind);
      if (!(value instanceof Integer) || (Integer) value < 0) {
        return null;
      }
      offsets.put(kind, (Integer) value);
    }
    return offsets;
  }

  /**
   * A cursor for the given counts.
   * @param offsets counts by kind
   * @return the cursor
   */
  public static String format(Map<String, Integer> offsets) {
    return JSON.serialize(offsets);
  }
}
