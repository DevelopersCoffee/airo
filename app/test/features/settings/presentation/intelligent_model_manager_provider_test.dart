import 'package:airo_app/core/services/local_runtime_preloader_service.dart';
import 'package:airo_app/features/agent_chat/application/assistant_model_preferences.dart';
import 'package:airo_app/features/agent_chat/domain/models/assistant_model_selection.dart';
import 'package:airo_app/features/settings/application/ai_model_management.dart';
import 'package:airo_app/features/settings/presentation/intelligent_model_manager_provider.dart';
import 'package:core_ai/core_ai.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockPreloader extends Mock implements LocalRuntimePreloaderService {}

class _MockManager extends Mock implements IntelligentModelManager {}

class _MockStorageManager extends Mock implements ModelStorageManager {}

class _MockDownloadService extends Mock implements ModelDownloadService {}

const _model = OfflineModelInfo(
  id: 'gemma-test',
  name: 'Gemma Test',
  family: ModelFamily.gemma,
  fileSizeBytes: 1024,
);

ModelPreloadReport _report(ModelPreloadEntryStatus status, String reason) {
  final now = DateTime(2026, 7, 29);
  return ModelPreloadReport(
    entries: [
      ModelPreloadReportEntry(
        runtimeId: _model.id,
        residentType: ResidentRuntimeType.text,
        status: status,
        reason: reason,
        duration: Duration.zero,
      ),
    ],
    startedAt: now,
    finishedAt: now,
    aborted: false,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('AiroModelWarmupGateway', () {
    late _MockPreloader preloader;
    late AiroModelWarmupGateway gateway;

    setUp(() {
      preloader = _MockPreloader();
      gateway = AiroModelWarmupGateway(preloader);
    });

    test('projects resident model ids', () {
      when(() => preloader.currentResidents).thenReturn([
        const ModelResidentSpec(
          id: 'resident-a',
          residentType: ResidentRuntimeType.text,
          estimatedMemoryBytes: 1,
        ),
        const ModelResidentSpec(
          id: 'resident-b',
          residentType: ResidentRuntimeType.tts,
          estimatedMemoryBytes: 1,
        ),
      ]);

      expect(gateway.residentModelIds, {'resident-a', 'resident-b'});
    });

    for (final testCase in [
      (
        entryStatus: ModelPreloadEntryStatus.warmed,
        reason: 'loaded',
        expected: ModelWarmupStatus.warmed,
      ),
      (
        entryStatus: ModelPreloadEntryStatus.warmed,
        reason: 'already_resident',
        expected: ModelWarmupStatus.alreadyResident,
      ),
      (
        entryStatus: ModelPreloadEntryStatus.skipped,
        reason: 'unavailable',
        expected: ModelWarmupStatus.unavailable,
      ),
      (
        entryStatus: ModelPreloadEntryStatus.failed,
        reason: 'runtime_failed',
        expected: ModelWarmupStatus.failed,
      ),
    ]) {
      test('maps ${testCase.entryStatus} (${testCase.reason})', () async {
        when(() => preloader.warmModel(_model)).thenAnswer(
          (_) async => _report(testCase.entryStatus, testCase.reason),
        );

        final result = await gateway.warm(_model);

        expect(result.modelId, _model.id);
        expect(result.status, testCase.expected);
        expect(result.detail, testCase.reason);
      });
    }
  });

  test('activation gateway keeps both selected-model ids in sync', () async {
    final gatewayProvider = Provider<ModelActivationGateway>(
      (ref) => AiroModelActivationGateway(ref),
    );
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final gateway = container.read(gatewayProvider);
    final assistantId = assistantModelIdForOfflineModel(_model.id);

    await gateway.activate(_model);

    expect(container.read(selectedModelIdProvider), _model.id);
    expect(container.read(selectedAssistantModelIdProvider), assistantId);

    await gateway.clear(_model);

    expect(container.read(selectedModelIdProvider), isNull);
    expect(container.read(selectedAssistantModelIdProvider), isNull);
  });

  test(
    'activation gateway preserves unrelated selections when clearing',
    () async {
      final gatewayProvider = Provider<ModelActivationGateway>(
        (ref) => AiroModelActivationGateway(ref),
      );
      final container = ProviderContainer();
      addTearDown(container.dispose);
      await container
          .read(selectedModelIdProvider.notifier)
          .setSelectedModel('other-model');
      await container
          .read(selectedAssistantModelIdProvider.notifier)
          .select('other-assistant');

      await container.read(gatewayProvider).clear(_model);

      expect(container.read(selectedModelIdProvider), 'other-model');
      expect(
        container.read(selectedAssistantModelIdProvider),
        'other-assistant',
      );
    },
  );

  test('manager provider composes the Airo runtime adapters', () {
    final container = ProviderContainer(
      overrides: [
        modelStorageManagerProvider.overrideWithValue(_MockStorageManager()),
        modelRegistryProvider.overrideWithValue(ModelRegistry()),
        modelDownloadServiceProvider.overrideWithValue(_MockDownloadService()),
      ],
    );
    addTearDown(container.dispose);

    expect(
      container.read(intelligentModelManagerProvider),
      isA<IntelligentModelManager>(),
    );
  });

  test('snapshot and list providers project the selected model', () async {
    final snapshot = ModelManagerSnapshot(
      models: const [
        ModelEntry(
          id: 'gemma-test',
          name: 'Gemma Test',
          version: 'Unversioned',
          description: '',
          sizeBytes: 1024,
          updateState: ModelUpdateState.notInstalled,
        ),
      ],
      downloadQueue: [],
      storageUsedBytes: 0,
    );
    final manager = _MockManager();
    when(
      () => manager.snapshot(activeModelId: _model.id),
    ).thenAnswer((_) async => snapshot);
    final container = ProviderContainer(
      overrides: [
        intelligentModelManagerProvider.overrideWithValue(manager),
        modelRegistryEventsProvider.overrideWith(
          (ref) => const Stream<ModelRegistryEvent>.empty(),
        ),
      ],
    );
    addTearDown(container.dispose);
    await container
        .read(selectedModelIdProvider.notifier)
        .setSelectedModel(_model.id);

    expect(
      await container.read(intelligentModelManagerSnapshotProvider.future),
      same(snapshot),
    );
    expect(
      container.read(intelligentModelsListProvider).requireValue,
      snapshot.models,
    );
    verify(() => manager.snapshot(activeModelId: _model.id)).called(1);
  });
}
