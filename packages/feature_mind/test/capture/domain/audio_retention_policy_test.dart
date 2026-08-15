import 'package:feature_mind/src/capture/domain/audio_retention_policy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AudioRetentionPolicy', () {
    test('round-trips through its storage value', () {
      for (final policy in AudioRetentionPolicy.values) {
        expect(
          AudioRetentionPolicy.fromStorageValue(policy.storageValue),
          policy,
        );
      }
    });

    test('an unknown or missing stored value falls back to keep', () {
      expect(
        AudioRetentionPolicy.fromStorageValue(null),
        AudioRetentionPolicy.keepAfterTranscript,
      );
      expect(
        AudioRetentionPolicy.fromStorageValue('not-a-real-value'),
        AudioRetentionPolicy.keepAfterTranscript,
      );
    });
  });
}
