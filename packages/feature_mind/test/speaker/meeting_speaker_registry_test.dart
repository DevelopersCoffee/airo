import 'package:feature_mind/src/speaker/meeting_speaker_registry.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('renameSpeaker stores display name on canonical label', () {
    const registry = MeetingSpeakerRegistry();
    final next = registry.renameSpeaker(label: 'sp0', displayName: 'Priya');
    expect(next.displayNameFor('sp0'), 'Priya');
    expect(next.encode(), contains('Priya'));
  });

  test('mergeSpeakers aliases labels for display', () {
    const registry = MeetingSpeakerRegistry(displayNames: {'sp0': 'Alice'});
    final merged = registry.mergeSpeakers(fromLabel: 'sp2', intoLabel: 'sp0');
    expect(merged.canonicalLabel('sp2'), 'sp0');
    expect(merged.displayNameFor('sp2'), 'Alice');
  });
}
