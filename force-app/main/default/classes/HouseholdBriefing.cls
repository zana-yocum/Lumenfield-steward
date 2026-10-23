/**
 * ST-08, S-20. One household's briefing data while AccountBriefingPrompt gathers it: the
 * household's facts, then six sections in the order the template reads them, and a line saying
 * there's no collections history when that's true. A section the person asking can't read never
 * counts as empty, so that line is never written for someone who simply can't see the records.
 */
public with sharing class HouseholdBriefing {
  /** Added when there's nothing on record for collections to talk about. */
  public static final String NO_HISTORY = 'COLLECTIONS HISTORY: none. Nothing is past due, and there are no promises, open disputes, commitments or contact attempts on record.';
  /** The most unpaid statements listed. */
  public static final Integer MAX_STATEMENTS = 6;
  /** The most payments listed. */
  public static final Integer MAX_PAYMENTS = 3;
  /** The most promises listed. */
  public static final Integer MAX_PROMISES = 5;
  /** The most contact attempts listed. */
  public static final Integer MAX_ATTEMPTS = 5;
  /** How far back a kept or broken promise still counts as recent. */
  public static final Integer RECENT_PROMISE_DAYS = 90;

  /** The household's past-due balance, which decides whether there's history to talk about. */
  public Decimal pastDueBalance;
  /** The household's own fields, one labelled line each. */
  public List<String> facts = new List<String>();
  /** Statements with a balance, oldest due first. */
  public PromptSection statements = new PromptSection(
    'UNPAID STATEMENTS (oldest due first)',
    'None.',
    MAX_STATEMENTS
  );
  /** The last payments, newest first. */
  public PromptSection payments = new PromptSection(
    'LAST PAYMENTS (newest first, up to ' + MAX_PAYMENTS + ')',
    'None recorded.',
    MAX_PAYMENTS
  );
  /** Open promises, and recent kept or broken ones. */
  public PromptSection promises = new PromptSection(
    'PROMISES TO PAY (open ones, and any due in the last ' +
      RECENT_PROMISE_DAYS +
      ' days; newest first, up to ' +
      MAX_PROMISES +
      ')',
    'None.',
    MAX_PROMISES
  );
  /** Open billing disputes with their next SLA milestone. */
  public PromptSection disputes = new PromptSection(
    'OPEN BILLING DISPUTES',
    'None.',
    null
  );
  /** Commitments made at signing, with their terms. */
  public PromptSection commitments = new PromptSection(
    'COMMITMENTS FROM SIGNING',
    'None.',
    null
  );
  /** Contact attempts in the last 30 days. */
  public PromptSection attempts = new PromptSection(
    'CONTACT ATTEMPTS (last 30 days, newest first, up to ' + MAX_ATTEMPTS + ')',
    'None in the last 30 days.',
    MAX_ATTEMPTS
  );

  /**
   * One of the six sections by its short name.
   * @param name statements, payments, promises, disputes, commitments or attempts
   * @return the section
   */
  public PromptSection section(String name) {
    return new Map<String, PromptSection>{
        'statements' => statements,
        'payments' => payments,
        'promises' => promises,
        'disputes' => disputes,
        'commitments' => commitments,
        'attempts' => attempts
      }
      .get(name);
  }

  /**
   * Whether there's nothing to talk about: nothing past due, and the promise, dispute,
   * commitment and contact sections all readable and empty.
   * @return true when there's no collections history
   */
  public Boolean hasNoHistory() {
    return (pastDueBalance ?? 0) <= 0 &&
      promises.isReadableAndEmpty() &&
      disputes.isReadableAndEmpty() &&
      commitments.isReadableAndEmpty() &&
      attempts.isReadableAndEmpty();
  }

  /**
   * The briefing data as prompt text: today's date, the facts, the no-history line when it
   * applies, then the six sections.
   * @return the text
   */
  public String toText() {
    List<String> text = new List<String>{
      'As of: ' + PromptFormat.day(Date.today())
    };
    text.addAll(facts);
    if (hasNoHistory()) {
      text.add(NO_HISTORY);
    }
    for (
      PromptSection part : new List<PromptSection>{
        statements,
        payments,
        promises,
        disputes,
        commitments,
        attempts
      }
    ) {
      text.add('');
      text.add(part.toText());
    }
    return String.join(text, '\n');
  }
}
