import 'package:feature_assistant/src/services/local_runtime_preloader_service.dart';
import 'package:feature_assistant/src/agent_chat/domain/models/assistant_runtime_ids.dart';
import 'package:feature_assistant/src/agent_chat/presentation/screens/model_library_screen.dart';
import 'package:core_ai/core_ai.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('builds local text adapters and no-op tts/stt hooks', () async {
    final preloader = _RecordingPreloader();
    final package = OfflineModelInfo(
      id: 'gemma-local',
      name: 'Gemma Local',
      family: ModelFamily.gemma,
      fileSizeBytes: 1024,
      provider: AIProvider.gemma,
      capabilities: const [ModelCapability.chat],
    );
    final candidate = AssistantModelCandidate(
      id: litertGemmaAssistantModelId,
      name: 'Gemma mobile package',
      runtime: 'LiteRT-LM local model',
      description: 'Local runtime',
      bestFor: const [AssistantTask.chat],
      tags: const ['Local'],
      privacyLabel: 'Prompt stays on device',
      sizeLabel: '1 GB',
      available: true,
      actionLabel: 'Start',
      local: true,
      package: package,
    );

    final service = LocalRuntimePreloaderService(
      preloader: preloader,
      loadAssistantModelLibrary: () async => AssistantModelLibraryState(
        task: AssistantTask.chat,
        deviceLabel: 'Pixel 9',
        platformLabel: 'ANDROID',
        candidates: [candidate],
        recommended: candidate,
        defaultPackages: {AssistantTask.chat: package},
      ),
      selectedModelId: () => litertGemmaAssistantModelId,
    );

    await service.preloadSelectedModels();

    expect(
      preloader.lastAdapters.map(
        (adapter) => adapter.residentSpec.residentType,
      ),
      containsAll([
        ResidentRuntimeType.text,
        ResidentRuntimeType.tts,
        ResidentRuntimeType.stt,
      ]),
    );
  });

  test('adds user-selected frequent models to startup warm-up', () async {
    final preloader = _RecordingPreloader();
    final frequentModel = ModelCatalog.bundledModels.first;
    final service = LocalRuntimePreloaderService(
      preloader: preloader,
      preloadPreferences: _FixedPreloadPreferences({frequentModel.id}),
    );

    await service.preloadSelectedModels();

    expect(
      preloader.lastAdapters.map((adapter) => adapter.residentSpec.id),
      contains(frequentModel.id),
    );
  });

  test(
    'does not warm default LiteRT when no model source is configured',
    () async {
      final preloader = _RecordingPreloader();
      final service = LocalRuntimePreloaderService(preloader: preloader);

      await service.preloadSelectedModels();

      expect(
        preloader.lastAdapters.map((adapter) => adapter.residentSpec.id),
        isNot(contains(litertGemmaAssistantModelId)),
      );
    },
  );
}

class _FixedPreloadPreferences implements ModelPreloadPreferences {
  _FixedPreloadPreferences(this.ids);

  final Set<String> ids;

  @override
  Future<Set<String>> loadModelIds() async => ids;

  @override
  Future<void> setEnabled(String modelId, bool enabled) async {}
}

class _RecordingPreloader extends ModelPreloader {
  _RecordingPreloader()
    : super(
        residencyManager: ModelResidencyManager(loadBudgetBytes: () async => 1),
      );

  List<ModelWarmupAdapter> lastAdapters = const [];

  @override
  Future<ModelPreloadReport> preloadSelectedModels({
    required List<ModelWarmupAdapter> adapters,
  }) async {
    lastAdapters = adapters;
    return ModelPreloadReport(
      entries: const [],
      startedAt: DateTime(2026, 6, 28),
      finishedAt: DateTime(2026, 6, 28),
      aborted: false,
    );
  }
}
