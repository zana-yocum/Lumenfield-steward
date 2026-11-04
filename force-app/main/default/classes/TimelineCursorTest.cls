/**
 * ST-15. Proves a timeline cursor reads back what was written, and that anything else is refused
 * rather than guessed at.
 */
@IsTest
private class TimelineCursorTest {
  @IsTest
  static void aCursorReadsBackWhatWasWritten() {
    Map<String, Integer> offsets = new Map<String, Integer>{
      'STATEMENT' => 20,
      'PAYMENT' => 7
    };

    Map<String, Integer> parsed = TimelineCursor.parse(
      TimelineCursor.format(offsets)
    );

    Assert.areEqual(offsets, parsed, 'Round trip');
  }

  @IsTest
  static void noCursorIsTheFirstPage() {
    Assert.isTrue(TimelineCursor.parse(null).isEmpty(), 'Null');
    Assert.isTrue(TimelineCursor.parse('  ').isEmpty(), 'Blank');
  }

  @IsTest
  static void anythingElseIsRefused() {
    for (
      String notACursor : new List<String>{
        'not json',
        '[1, 2]',
        '{"STATEMENT": -1}',
        '{"STATEMENT": "twenty"}',
        '{"STATEMENT": 2.5}'
      }
    ) {
      Assert.isNull(TimelineCursor.parse(notACursor), 'Refused: ' + notACursor);
    }
  }
}
