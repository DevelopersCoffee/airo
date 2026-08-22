import 'package:feature_mind/src/capture/domain/live_speaker_label.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('maps sp labels to Speaker N', () {
    expect(formatLiveSpeakerLabel('sp0'), 'Speaker 1');
    expect(formatLiveSpeakerLabel('sp1'), 'Speaker 2');
  });

  test('defaults to Speaker 1 when unknown', () {
    expect(formatLiveSpeakerLabel(null), 'Speaker 1');
    expect(formatLiveSpeakerLabel(''), 'Speaker 1');
  });

  test('preserves resolved display names', () {
    expect(formatLiveSpeakerLabel('Rahul'), 'Rahul');
  });

  test('formats segment clock from start ms', () {
    expect(formatLiveSegmentClock(0), '00:00');
    expect(formatLiveSegmentClock(65000), '01:05');
  });
}
