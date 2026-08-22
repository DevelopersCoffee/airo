import 'package:feature_mind/src/mind_diarization.dart';
import 'package:feature_mind/src/speaker/meeting_speaker_registry.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('mindSpeakerDisplayLabel uses registry name when set', () {
    final registry = MeetingSpeakerRegistry.empty.renameSpeaker(
      label: 'sp1',
      displayName: 'Raj',
    );
    expect(mindSpeakerDisplayLabel('sp1', registry: registry), 'Raj');
  });
}
