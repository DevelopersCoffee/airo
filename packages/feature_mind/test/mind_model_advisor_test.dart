import 'package:core_ai/core_ai.dart';
import 'package:core_entitlements/core_entitlements.dart';
import 'package:feature_mind/src/mind_indic_intelligence.dart';
import 'package:feature_mind/src/mind_model_advisor.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

OfflineModelInfo _scribeModel({
  required String id,
  required String name,
  bool downloaded = false,
  int sizeBytes = 1000,
}) => OfflineModelInfo(
  id: id,
  name: name,
  family: ModelFamily.other,
  fileSizeBytes: sizeBytes,
  filePath: downloaded ? '/tmp/$id' : null,
);

Map<String, OfflineModelInfo> _fullCatalog({bool sarvamInstalled = false}) => {
  MindScribeModelIds.whisperMultilingual: _scribeModel(
    id: MindScribeModelIds.whisperMultilingual,
    name: 'Whisper Tiny (Multilingual)',
    downloaded: true,
    sizeBytes: 77691713,
  ),
  MindScribeModelIds.whisperEnglish: _scribeModel(
    id: MindScribeModelIds.whisperEnglish,
    name: 'Whisper Tiny (English)',
    sizeBytes: 77704715,
  ),
  MindScribeModelIds.qwenGeneration: _scribeModel(
    id: MindScribeModelIds.qwenGeneration,
    name: 'Qwen2.5 0.5B Instruct (Q4_K_M)',
    downloaded: true,
    sizeBytes: 397807424,
  ),
  MindScribeModelIds.sarvamGeneration: _scribeModel(
    id: MindScribeModelIds.sarvamGeneration,
    name: 'Sarvam-1 (Q4_K_M)',
    downloaded: sarvamInstalled,
    sizeBytes: 1547736928,
  ),
};

MindIndicCapability _desktopProCapability({MemoryInfo? memory}) {
  debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
  return MindIndicCapability(
    entitlements: const LaunchPromoEntitlements(),
    memoryInfo: memory ??
        MemoryInfo(
          totalBytes: kMindIndicMinTotalRamBytes,
          availableBytes: kMindIndicMinAvailableRamBytes,
        ),
  );
}

void main() {
  group('MindModelAdvisor', () {
    test('desktop pro with RAM features Sarvam stack', () {
      final advisor = MindModelAdvisor();
      final result = advisor.recommend(
        capability: _desktopProCapability(),
        generationMode: MindIndicGenerationMode.auto,
        scribeModelsById: _fullCatalog(),
      );

      expect(result.featured.generationModelId, MindScribeModelIds.sarvamGeneration);
      expect(result.featured.badge, MindModelRecommendationBadge.bestOverall);
      expect(result.featured.action, MindModelRecommendationAction.download);
      debugDefaultTargetPlatformOverride = null;
    });

    test('desktop pro low RAM features Qwen stack', () {
      final advisor = MindModelAdvisor();
      final result = advisor.recommend(
        capability: _desktopProCapability(
          memory: MemoryInfo.fromMegabytes(totalMB: 6000, availableMB: 2000),
        ),
        generationMode: MindIndicGenerationMode.auto,
        scribeModelsById: _fullCatalog(),
      );

      expect(
        result.featured.generationModelId,
        MindScribeModelIds.qwenGeneration,
      );
      final sarvamAlternate = result.alternates.firstWhere(
        (alt) => alt.generationModelId == MindScribeModelIds.sarvamGeneration,
      );
      expect(sarvamAlternate.action, MindModelRecommendationAction.disabled);
      debugDefaultTargetPlatformOverride = null;
    });

    test('mobile hides Sarvam from featured stack', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      final advisor = MindModelAdvisor();
      final result = advisor.recommend(
        capability: MindIndicCapability(
          entitlements: const LaunchPromoEntitlements(),
          memoryInfo: MemoryInfo(
            totalBytes: kMindIndicMinTotalRamBytes,
            availableBytes: kMindIndicMinAvailableRamBytes,
          ),
        ),
        generationMode: MindIndicGenerationMode.auto,
        scribeModelsById: _fullCatalog(),
      );

      expect(
        result.featured.generationModelId,
        MindScribeModelIds.qwenGeneration,
      );
      debugDefaultTargetPlatformOverride = null;
    });

    test('installed stack offers Try it', () {
      final advisor = MindModelAdvisor();
      final result = advisor.recommend(
        capability: _desktopProCapability(),
        generationMode: MindIndicGenerationMode.enhancedIndic,
        scribeModelsById: _fullCatalog(sarvamInstalled: true),
      );

      expect(result.featured.action, MindModelRecommendationAction.tryNow);
      debugDefaultTargetPlatformOverride = null;
    });

    test('includes Sarvam Edge speech stub', () {
      final advisor = MindModelAdvisor();
      final result = advisor.recommend(
        capability: _desktopProCapability(),
        generationMode: MindIndicGenerationMode.auto,
        scribeModelsById: _fullCatalog(),
      );

      expect(result.speechStub?.headline, 'Sarvam Edge ASR');
      expect(
        result.speechStub?.action,
        MindModelRecommendationAction.disabled,
      );
      debugDefaultTargetPlatformOverride = null;
    });
  });
}
