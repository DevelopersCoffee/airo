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
    memoryInfo:
        memory ??
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

      expect(
        result.featured.generationModelId,
        MindScribeModelIds.sarvamGeneration,
      );
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

    test('does not invent unpublished speech models', () {
      final advisor = MindModelAdvisor();
      final result = advisor.recommend(
        capability: _desktopProCapability(),
        generationMode: MindIndicGenerationMode.auto,
        scribeModelsById: _fullCatalog(),
      );

      expect(result.speechStub, isNotNull);
      expect(
        result.featured.generationModelId,
        MindScribeModelIds.sarvamGeneration,
      );
      expect(
        result.featured.speechModelId,
        MindScribeModelIds.whisperMultilingual,
      );
      debugDefaultTargetPlatformOverride = null;
    });

    test('uses catalog names and descriptions, not invented copy', () {
      final advisor = MindModelAdvisor();
      final catalog = Map<String, OfflineModelInfo>.from(_fullCatalog());
      catalog[MindScribeModelIds.qwenGeneration] = OfflineModelInfo(
        id: MindScribeModelIds.qwenGeneration,
        name: 'Catalog minutes pack',
        family: ModelFamily.other,
        fileSizeBytes: 397807424,
        filePath: '/tmp/qwen',
        description: 'Catalog minutes description.',
      );
      catalog[MindScribeModelIds.whisperMultilingual] = OfflineModelInfo(
        id: MindScribeModelIds.whisperMultilingual,
        name: 'Catalog speech pack',
        family: ModelFamily.other,
        fileSizeBytes: 77691713,
        filePath: '/tmp/whisper',
        description: 'Catalog speech description.',
      );

      final result = advisor.recommend(
        capability: _desktopProCapability(
          memory: MemoryInfo.fromMegabytes(totalMB: 6000, availableMB: 2000),
        ),
        generationMode: MindIndicGenerationMode.standard,
        scribeModelsById: catalog,
      );

      expect(
        result.featured.generationModelId,
        MindScribeModelIds.qwenGeneration,
      );
      expect(
        result.featured.speechModelId,
        MindScribeModelIds.whisperMultilingual,
      );
      expect(
        result.featured.runtimeNote,
        contains('Catalog minutes description.'),
      );
      expect(
        result.featured.runtimeNote,
        contains('Catalog speech description.'),
      );
      expect(result.speechStub, isNotNull);
      debugDefaultTargetPlatformOverride = null;
    });
  });
}
