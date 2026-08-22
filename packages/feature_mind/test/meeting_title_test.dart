import 'package:feature_mind/src/meeting_title.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('generic timestamp titles are replaced from the transcript', () {
    const transcript =
        '[00:00:00] sp0: So my name is Quintang. I was a chemist before. '
        'So I got my PhD in Chinese Academy of Science. My PhD in the '
        'Science is about the LISM on the first phase of the film.';
    final title = resolveMeetingTitle(
      requested: 'Meeting 2026-08-23 03:01:00.086253',
      transcript: transcript,
    );
    expect(title, contains('Quintang'));
    expect(title.toLowerCase(), anyOf(contains('chemist'), contains('phd')));
    expect(title, isNot(contains('2026-08-23')));
  });

  test('an explicit title is kept', () {
    expect(
      resolveMeetingTitle(
        requested: 'Platform standup',
        transcript: 'We will add three pods.',
      ),
      'Platform standup',
    );
  });

  test('Meeting N is treated as a placeholder', () {
    expect(isGenericMeetingTitle('Meeting 4'), isTrue);
    expect(isGenericMeetingTitle('Platform standup'), isFalse);
  });
}
