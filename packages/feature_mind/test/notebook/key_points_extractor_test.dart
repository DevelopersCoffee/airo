import 'package:feature_mind/src/notebook/domain/key_points_extractor.dart';
import 'package:feature_mind/src/notebook/domain/notebook_summary.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const extractor = KeyPointsExtractor();

  test('prefers action items and markdown bullets over raw transcript', () {
    final points = extractor.extract(
      minutes: '''
# Summary
A long meeting.

## Key points
- Adopt Kubernetes for staging
- Freeze hiring until April

## Notes
More prose that is not a bullet.
''',
      transcript: 'This sentence should not win because bullets exist.',
      actionItems: ['Ping design about the banner'],
    );

    expect(points, [
      'Ping design about the banner',
      'Adopt Kubernetes for staging',
      'Freeze hiring until April',
    ]);
  });

  test('falls back to transcript sentences when minutes have no lists', () {
    final points = extractor.extract(
      transcript:
          'We will launch on Tuesday. Priya owns the checklist. The budget is frozen.',
    );

    expect(points.first, contains('launch on Tuesday'));
    expect(points, isNot(isEmpty));
  });

  test('summary reads an explicit Summary section then clips', () {
    expect(
      NotebookSummary.fromMinutes('''
# Summary
Ship the notebook this week.

# Transcript
ignored
'''),
      'Ship the notebook this week.',
    );
    expect(
      NotebookSummary.fromMinutes('Just one paragraph about shipping.'),
      'Just one paragraph about shipping.',
    );
  });
}
