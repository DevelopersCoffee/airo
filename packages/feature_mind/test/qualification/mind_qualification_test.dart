import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:feature_mind/src/qualification/mind_qualification.dart';

void main() {
  group('MindQualificationState', () {
    test('is ordered least-to-most qualified', () {
      expect(
        MindQualificationState.unsupported.rank <
            MindQualificationState.experimental.rank,
        isTrue,
      );
      expect(
        MindQualificationState.experimental.rank <
            MindQualificationState.preview.rank,
        isTrue,
      );
      expect(
        MindQualificationState.preview.rank <
            MindQualificationState.production.rank,
        isTrue,
      );
    });

    test('atMost caps a state down to the ceiling and never up', () {
      expect(
        MindQualificationState.production.atMost(
          MindQualificationState.preview,
        ),
        MindQualificationState.preview,
      );
      expect(
        MindQualificationState.experimental.atMost(
          MindQualificationState.production,
        ),
        MindQualificationState.experimental,
      );
      expect(
        MindQualificationState.preview.atMost(
          MindQualificationState.unsupported,
        ),
        MindQualificationState.unsupported,
      );
    });

    test('isAtLeast compares by rank', () {
      expect(
        MindQualificationState.preview.isAtLeast(
          MindQualificationState.experimental,
        ),
        isTrue,
      );
      expect(
        MindQualificationState.experimental.isAtLeast(
          MindQualificationState.preview,
        ),
        isFalse,
      );
    });
  });

  group('resolveMindPlatform', () {
    test('web wins regardless of platform', () {
      expect(
        resolveMindPlatform(platform: TargetPlatform.android, isWeb: true),
        MindPlatform.web,
      );
    });

    test('maps desktop hosts to a single desktop platform', () {
      for (final host in [
        TargetPlatform.macOS,
        TargetPlatform.linux,
        TargetPlatform.windows,
      ]) {
        expect(
          resolveMindPlatform(platform: host, isWeb: false),
          MindPlatform.desktop,
        );
      }
    });

    test('maps mobile hosts', () {
      expect(
        resolveMindPlatform(platform: TargetPlatform.android, isWeb: false),
        MindPlatform.android,
      );
      expect(
        resolveMindPlatform(platform: TargetPlatform.iOS, isWeb: false),
        MindPlatform.ios,
      );
    });
  });

  group('MindQualificationMatrix.current', () {
    final matrix = MindQualificationMatrix.current();

    test(
      'declares no capability as production on any platform (honest state)',
      () {
        for (final platform in MindPlatform.values) {
          for (final capability in MindCapability.values) {
            expect(
              matrix.declaredCeiling(capability, platform),
              isNot(MindQualificationState.production),
              reason:
                  '${capability.label} on ${platform.label} must not be declared '
                  'production before qualification gates pass',
            );
          }
        }
      },
    );

    test('desktop live STT tops out at preview', () {
      expect(
        matrix.declaredCeiling(MindCapability.liveStt, MindPlatform.desktop),
        MindQualificationState.preview,
      );
    });

    test(
      'android live intelligence is unsupported (no native fan-out yet)',
      () {
        expect(
          matrix.declaredCeiling(MindCapability.liveStt, MindPlatform.android),
          MindQualificationState.unsupported,
        );
        expect(
          matrix.declaredCeiling(
            MindCapability.liveInsights,
            MindPlatform.android,
          ),
          MindQualificationState.unsupported,
        );
      },
    );

    test('android post-recording capabilities are declared preview', () {
      expect(
        matrix.declaredCeiling(MindCapability.offlineStt, MindPlatform.android),
        MindQualificationState.preview,
      );
      expect(
        matrix.declaredCeiling(
          MindCapability.postRecordingIr,
          MindPlatform.android,
        ),
        MindQualificationState.preview,
      );
    });

    test('iOS and web are unsupported across the board', () {
      for (final capability in MindCapability.values) {
        expect(
          matrix.declaredCeiling(capability, MindPlatform.ios),
          MindQualificationState.unsupported,
        );
        expect(
          matrix.declaredCeiling(capability, MindPlatform.web),
          MindQualificationState.unsupported,
        );
      }
    });
  });

  group('MindQualificationResolver', () {
    final resolver = MindQualificationResolver();

    const desktopLive = MindRuntimeCapabilitySignals(
      nativeBridgeAvailable: true,
      recordingSupported: true,
      liveHostSupported: true,
    );

    test('desktop with full signals reports declared preview for live STT', () {
      final q = resolver.resolve(
        MindCapability.liveStt,
        MindPlatform.desktop,
        desktopLive,
      );
      expect(q.state, MindQualificationState.preview);
      expect(q.isAvailable, isTrue);
    });

    test('missing native bridge collapses every capability to unsupported', () {
      const noBridge = MindRuntimeCapabilitySignals(
        nativeBridgeAvailable: false,
        recordingSupported: true,
        liveHostSupported: true,
      );
      final resolved = resolver.resolveMatrix(MindPlatform.desktop, noBridge);
      for (final q in resolved.values) {
        expect(q.state, MindQualificationState.unsupported);
        expect(q.isAvailable, isFalse);
      }
    });

    test(
      'live capabilities collapse when the host cannot run the pipeline',
      () {
        const batchOnly = MindRuntimeCapabilitySignals(
          nativeBridgeAvailable: true,
          recordingSupported: true,
          liveHostSupported: false,
        );
        final resolved = resolver.resolveMatrix(
          MindPlatform.android,
          batchOnly,
        );
        // Live rows unsupported...
        expect(
          resolved[MindCapability.liveStt]!.state,
          MindQualificationState.unsupported,
        );
        expect(
          resolved[MindCapability.liveInsights]!.state,
          MindQualificationState.unsupported,
        );
        // ...but post-recording rows still available (capped at declared).
        expect(
          resolved[MindCapability.postRecordingIr]!.state,
          MindQualificationState.preview,
        );
        expect(
          resolved[MindCapability.offlineStt]!.state,
          MindQualificationState.preview,
        );
      },
    );

    test('web is always unsupported even if signals claim otherwise', () {
      const lyingSignals = MindRuntimeCapabilitySignals(
        nativeBridgeAvailable: true,
        recordingSupported: true,
        liveHostSupported: true,
      );
      final resolved = resolver.resolveMatrix(MindPlatform.web, lyingSignals);
      for (final q in resolved.values) {
        expect(q.state, MindQualificationState.unsupported);
      }
    });

    test('resolved state never exceeds the declared ceiling (no production '
        'from a flag)', () {
      for (final platform in MindPlatform.values) {
        final resolved = resolver.resolveMatrix(platform, desktopLive);
        for (final q in resolved.values) {
          expect(
            q.state.rank <= q.declaredCeiling.rank,
            isTrue,
            reason:
                '${q.capability.label} on ${platform.label} resolved '
                '${q.state} above declared ${q.declaredCeiling}',
          );
          expect(q.isProduction, isFalse);
        }
      }
    });

    test('recording drops to unsupported when no recorder is present', () {
      const noRecorder = MindRuntimeCapabilitySignals(
        nativeBridgeAvailable: true,
        recordingSupported: false,
        liveHostSupported: false,
      );
      final q = resolver.resolve(
        MindCapability.recording,
        MindPlatform.desktop,
        noRecorder,
      );
      expect(q.state, MindQualificationState.unsupported);
    });
  });

  group('MindRuntimeCapabilitySignals.forHost', () {
    test('web reports no bridge, no recording, no live', () {
      final signals = MindRuntimeCapabilitySignals.forHost(
        nativeBridgeAvailable: true,
        platform: TargetPlatform.android,
        isWeb: true,
      );
      expect(signals.nativeBridgeAvailable, isFalse);
      expect(signals.recordingSupported, isFalse);
      expect(signals.liveHostSupported, isFalse);
    });

    test('desktop host reports live support when the bridge is available', () {
      final signals = MindRuntimeCapabilitySignals.forHost(
        nativeBridgeAvailable: true,
        platform: TargetPlatform.macOS,
        isWeb: false,
      );
      expect(signals.nativeBridgeAvailable, isTrue);
      expect(signals.recordingSupported, isTrue);
      expect(signals.liveHostSupported, isTrue);
    });

    test('android host has no live support even with the bridge', () {
      final signals = MindRuntimeCapabilitySignals.forHost(
        nativeBridgeAvailable: true,
        platform: TargetPlatform.android,
        isWeb: false,
      );
      expect(signals.liveHostSupported, isFalse);
      expect(signals.recordingSupported, isTrue);
    });
  });
}
