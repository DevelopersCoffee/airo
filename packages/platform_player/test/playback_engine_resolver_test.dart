import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:platform_player/platform_player.dart';

void main() {
  group('currentAiroPlaybackPlatform', () {
    tearDown(() {
      debugDefaultTargetPlatformOverride = null;
    });

    const table = <TargetPlatform, AiroPlaybackPlatform>{
      TargetPlatform.iOS: AiroPlaybackPlatform.ios,
      TargetPlatform.macOS: AiroPlaybackPlatform.macos,
      TargetPlatform.windows: AiroPlaybackPlatform.windows,
      TargetPlatform.linux: AiroPlaybackPlatform.linux,
      TargetPlatform.fuchsia: AiroPlaybackPlatform.unknown,
    };

    for (final entry in table.entries) {
      test('${entry.key.name} maps to ${entry.value.stableId}', () {
        debugDefaultTargetPlatformOverride = entry.key;
        expect(currentAiroPlaybackPlatform(), entry.value);
      });
    }

    test('android without isAndroidTv resolves to androidMobile', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      expect(currentAiroPlaybackPlatform(), AiroPlaybackPlatform.androidMobile);
    });

    test('android with isAndroidTv: true resolves to androidTv', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      expect(
        currentAiroPlaybackPlatform(isAndroidTv: true),
        AiroPlaybackPlatform.androidTv,
      );
    });
  });


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

  group('AiroPlaybackEngineResolver.resolveFallback', () {
    const resolver = AiroPlaybackEngineResolver();

    AiroPlaybackDeviceProfile profileFor(AiroPlaybackPlatform platform) =>
        AiroPlaybackDeviceProfile(platform: platform);

    test('androidTv: no fallback (mpv not bundled — storage-starved)', () {
      expect(
        resolver.resolveFallback(profileFor(AiroPlaybackPlatform.androidTv)),
        isNull,
      );
    });

    test('web: no fallback (media_kit web is weak)', () {
      expect(
        resolver.resolveFallback(profileFor(AiroPlaybackPlatform.web)),
        isNull,
      );
    });

    test('windows: no fallback (mpv is already primary)', () {
      expect(
        resolver.resolveFallback(profileFor(AiroPlaybackPlatform.windows)),
        isNull,
      );
    });

    test('linux: no fallback (mpv is already primary)', () {
      expect(
        resolver.resolveFallback(profileFor(AiroPlaybackPlatform.linux)),
        isNull,
      );
    });

    test('unknown: no fallback (platform unrecognized)', () {
      expect(
        resolver.resolveFallback(profileFor(AiroPlaybackPlatform.unknown)),
        isNull,
      );
    });

    test('androidMobile: mpv is the fallback when hints are empty', () {
      expect(
        resolver.resolveFallback(profileFor(AiroPlaybackPlatform.androidMobile)),
        AiroPlaybackBackendKind.mpv,
      );
    });

    test('ios: mpv is the fallback when hints are empty', () {
      expect(
        resolver.resolveFallback(profileFor(AiroPlaybackPlatform.ios)),
        AiroPlaybackBackendKind.mpv,
      );
    });

    test('macos: mpv is the fallback when hints are empty', () {
      expect(
        resolver.resolveFallback(profileFor(AiroPlaybackPlatform.macos)),
        AiroPlaybackBackendKind.mpv,
      );
    });

    test('android mobile with sub-2GB RAM: fallback disabled', () {
      expect(
        resolver.resolveFallback(
          profileFor(AiroPlaybackPlatform.androidMobile),
          hints: const AiroPlaybackFallbackDeviceHints(totalRamMb: 1024),
        ),
        isNull,
      );
    });

    test('android mobile at exactly 2GB RAM: fallback enabled (boundary)', () {
      expect(
        resolver.resolveFallback(
          profileFor(AiroPlaybackPlatform.androidMobile),
          hints: const AiroPlaybackFallbackDeviceHints(
            totalRamMb: kMpvFallbackMinRamMb,
          ),
        ),
        AiroPlaybackBackendKind.mpv,
      );
    });

    test('missing hardware H.264 decoder: fallback disabled', () {
      expect(
        resolver.resolveFallback(
          profileFor(AiroPlaybackPlatform.androidMobile),
          hints: const AiroPlaybackFallbackDeviceHints(
            hasHardwareH264Decoder: false,
          ),
        ),
        isNull,
      );
    });

    test('unknown RAM does not punish the device (fallback allowed)', () {
      expect(
        resolver.resolveFallback(
          profileFor(AiroPlaybackPlatform.androidMobile),
          hints: const AiroPlaybackFallbackDeviceHints(totalRamMb: null),
        ),
        AiroPlaybackBackendKind.mpv,
      );
    });
  });
}
