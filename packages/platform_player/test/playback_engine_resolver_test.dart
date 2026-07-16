import 'package:flutter_test/flutter_test.dart';
import 'package:platform_player/platform_player.dart';

void main() {
  group('AiroPlaybackEngineResolver', () {
    const resolver = AiroPlaybackEngineResolver();

    const table = <AiroPlaybackPlatform, AiroPlaybackBackendKind>{
      AiroPlaybackPlatform.web: AiroPlaybackBackendKind.videoPlayer,
      AiroPlaybackPlatform.androidMobile: AiroPlaybackBackendKind.videoPlayer,
      AiroPlaybackPlatform.androidTv: AiroPlaybackBackendKind.videoPlayer,
      AiroPlaybackPlatform.ios: AiroPlaybackBackendKind.videoPlayer,
      AiroPlaybackPlatform.macos: AiroPlaybackBackendKind.videoPlayer,
      AiroPlaybackPlatform.windows: AiroPlaybackBackendKind.mpv,
      AiroPlaybackPlatform.linux: AiroPlaybackBackendKind.mpv,
      AiroPlaybackPlatform.unknown: AiroPlaybackBackendKind.unavailable,
    };

    for (final entry in table.entries) {
      test('${entry.key.stableId} resolves to ${entry.value.stableId}', () {
        final profile = AiroPlaybackDeviceProfile(platform: entry.key);
        expect(resolver.resolve(profile), entry.value);
      });
    }

    test('resolver is total: never returns null for any platform', () {
      for (final platform in AiroPlaybackPlatform.values) {
        final result = resolver.resolve(
          AiroPlaybackDeviceProfile(platform: platform),
        );
        expect(result, isNotNull);
      }
    });

    test('every platform value is covered by the resolver table', () {
      expect(table.keys.toSet(), AiroPlaybackPlatform.values.toSet());
    });
  });
}
