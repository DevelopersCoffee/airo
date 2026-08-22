import 'package:feature_mind/src/meeting_ir/meeting_minutes_content.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('empty MoM template is treated as no minutes', () {
    const minutes = '''
# Minutes of Meeting

**Meeting:** Meeting 2026-08-23 03:01:00.086253

## Meeting Objective

No objective was recorded for this meeting.

## Key Discussion Points

No discussion points were recorded for this meeting.

## Decisions & Direction

_No decisions recorded._

## Action Items

_No action items recorded._

## Next Steps

_No further steps recorded._
''';
    expect(isEmptyMeetingMinutes(minutes), isTrue);
  });

  test('minutes with a real finding are kept', () {
    expect(
      isEmptyMeetingMinutes(
        '# Minutes of Meeting\n\n## Meeting Objective\n\n'
        'Align on the LISM battery timeline.',
      ),
      isFalse,
    );
  });
}
