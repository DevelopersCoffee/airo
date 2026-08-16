import 'package:feature_mind/src/bridges/mind_speech_bridge.dart';
import 'package:feature_mind/src/mind_diarization.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('applySoloSpeakerDiarization assigns sp0 to every segment', () {
    const segments = [
      TranscriptSegment(id: 's0', startMs: 0, endMs: 500, text: 'hello'),
      TranscriptSegment(id: 's1', startMs: 500, endMs: 900, text: 'world'),
    ];

    final diarized = applySoloSpeakerDiarization(segments);

    expect(
      diarized,
      [
        const TranscriptSegment(
          id: 's0',
          startMs: 0,
          endMs: 500,
          text: 'hello',
          speakerLabel: kMindSoloSpeakerLabel,
        ),
        const TranscriptSegment(
          id: 's1',
          startMs: 500,
          endMs: 900,
          text: 'world',
          speakerLabel: kMindSoloSpeakerLabel,
        ),
      ],
    );
  });

  test('empty segments stay empty', () {
    expect(applySoloSpeakerDiarization(const []), isEmpty);
  });

  test('ensureSpeakerLabels keeps rust-assigned labels', () {
    const segments = [
      TranscriptSegment(
        id: 's0',
        startMs: 0,
        endMs: 500,
        text: 'hello',
        speakerLabel: 'sp1',
      ),
    ];
    final labeled = ensureSpeakerLabels(segments);
    expect(labeled.single.speakerLabel, 'sp1');
  });

  test('ensureSpeakerLabels applies solo fallback when labels missing', () {
    const segments = [
      TranscriptSegment(id: 's0', startMs: 0, endMs: 500, text: 'hello'),
    ];
    final labeled = ensureSpeakerLabels(segments);
    expect(labeled.single.speakerLabel, kMindSoloSpeakerLabel);
  });

  test('formatMindSpeakerLabel maps spN to Speaker N+1', () {
    expect(formatMindSpeakerLabel('sp0'), 'Speaker 1');
    expect(formatMindSpeakerLabel('sp2'), 'Speaker 3');
    expect(formatMindSpeakerLabel('guest'), 'guest');
  });
}
