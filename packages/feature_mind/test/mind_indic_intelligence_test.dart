import 'package:core_ai/core_ai.dart';
import 'package:core_entitlements/core_entitlements.dart';
import 'package:feature_mind/src/mind_indic_intelligence.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('MindIndicCapability', () {
    test('auto prefers Indic on entitled desktop with enough RAM', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.linux;
      final capability = MindIndicCapability(
        entitlements: const LaunchPromoEntitlements(),
        memoryInfo: MemoryInfo(
          totalBytes: kMindIndicMinTotalRamBytes,
          availableBytes: kMindIndicMinAvailableRamBytes,
        ),
      );

      expect(
        capability.shouldPreferIndicGeneration(MindIndicGenerationMode.auto),
        isTrue,
      );
      debugDefaultTargetPlatformOverride = null;
    });

    test('standard never prefers Indic', () {
      final capability = MindIndicCapability(
        entitlements: const LaunchPromoEntitlements(),
        memoryInfo: MemoryInfo(
          totalBytes: kMindIndicMinTotalRamBytes,
          availableBytes: kMindIndicMinAvailableRamBytes,
        ),
      );

      expect(
        capability.shouldPreferIndicGeneration(
          MindIndicGenerationMode.standard,
        ),
        isFalse,
      );
    });

    test('enhanced always prefers when pro enabled', () {
      final capability = MindIndicCapability(
        entitlements: const LaunchPromoEntitlements(),
      );

      expect(
        capability.shouldPreferIndicGeneration(
          MindIndicGenerationMode.enhancedIndic,
        ),
        isTrue,
      );
    });

    test('denied when pro feature disabled', () {
      const capability = MindIndicCapability(entitlements: NoEntitlements());

      expect(
        capability.shouldPreferIndicGeneration(MindIndicGenerationMode.auto),
        isFalse,
      );
    });

    test('Sarvam speech not available on public artifacts yet', () {
      final capability = MindIndicCapability(
        entitlements: const LaunchPromoEntitlements(),
      );

      expect(
        capability.shouldPreferIndicSpeech(MindIndicSpeechMode.sarvamEdge),
        isFalse,
      );
    });
  });
}
