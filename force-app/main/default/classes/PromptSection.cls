/**
 * ST-08, ST-09, S-20. One titled part of the data the rep assistant sends with a prompt: its
 * lines, a sentence for when there are none, or a plain statement that the person asking can't
 * read it. Unreadable isn't the same as empty, and the templates tell the model which is which.
 */
public with sharing class PromptSection {
  /** What a part the person asking can't read says. */
  public static final String NOT_AVAILABLE = 'Not available to you.';

  private final String title;
  private final String emptyText;
  private final Integer maxLines;
  private final List<String> lines = new List<String>();
  private Boolean available = true;

  /**
   * An empty section.
   * @param title its heading, such as OPEN BILLING DISPUTES
   * @param emptyText what it says when it has no lines, such as None.
   * @param maxLines the most lines it keeps; null for no limit
   */
  public PromptSection(String title, String emptyText, Integer maxLines) {
    this.title = title;
    this.emptyText = emptyText;
    this.maxLines = maxLines;
  }

  /**
   * Adds a line, unless the section is already full.
   * @param line the line
   */
  public void add(String line) {
    if (maxLines == null || lines.size() < maxLines) {
      lines.add(line);
    }
  }

  /** Marks the section as one the person asking can't read. */
  public void markUnavailable() {
    available = false;
  }

  /**
   * Whether the section is readable and has nothing in it.
   * @return true only for a readable, empty section
   */
  public Boolean isReadableAndEmpty() {
    return available && lines.isEmpty();
  }

  /**
   * The section as prompt text: the heading, then its lines as a list, the empty sentence, or
   * NOT_AVAILABLE.
   * @return the text
   */
  public String toText() {
    if (!available) {
      return title + '\n' + NOT_AVAILABLE;
    }
    if (lines.isEmpty()) {
      return title + '\n' + emptyText;
    }
    return title + '\n- ' + String.join(lines, '\n- ');
  }
}
