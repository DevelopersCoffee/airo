import 'package:feature_iptv/application/caption_webvtt_parser.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parseWebVtt reads cue timing and text', () {
    const source = '''
WEBVTT

00:00:01.000 --> 00:00:04.000
Hello world

00:00:05.000 --> 00:00:07.500
Second line
''';

    final cues = parseWebVtt(source);
    expect(cues, hasLength(2));
    expect(cues.first.text, 'Hello world');
    expect(cues.first.start, const Duration(seconds: 1));
    expect(cues.first.end, const Duration(seconds: 4));
  });

  test('captionCueAt returns active cue for position', () {
    final cues = parseWebVtt('''
WEBVTT

00:00:01.000 --> 00:00:04.000
Hello
''');

    expect(captionCueAt(cues, const Duration(seconds: 2))?.text, 'Hello');
    expect(captionCueAt(cues, const Duration(seconds: 5)), isNull);
  });
}
