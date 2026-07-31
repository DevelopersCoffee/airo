import 'package:airo_app/features/settings/application/ai_model_management.dart';
import 'package:airo_app/features/settings/presentation/intelligent_model_manager_provider.dart';
import 'package:core_ai/core_ai.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('wires the manager through app providers without platform policy', () {
    final registry = ModelRegistry();
    registry.registerModel(
      const OfflineModelInfo(
        id: 'provider-model',
        name: 'Provider model',
        family: ModelFamily.gemma,
        fileSizeBytes: 1024,
      ),
    );
    final container = ProviderContainer(
      overrides: [modelRegistryProvider.overrideWithValue(registry)],
    );
    addTearDown(container.dispose);
    addTearDown(registry.dispose);

    final manager = container.read(intelligentModelManagerProvider);

    expect(manager, isA<IntelligentModelManager>());
  });

  test('projects manager snapshots into compatibility model lists', () async {
    const entry = ModelEntry(
      id: 'projected-model',
      name: 'Projected model',
      version: '1',
      description: 'Projected through AsyncValue',
      sizeBytes: 2048,
      isDownloaded: true,
      updateState: ModelUpdateState.upToDate,
    );
    const snapshot = ModelManagerSnapshot(
      models: [entry],
      downloadQueue: [],
      storageUsedBytes: 2048,
    );
    final container = ProviderContainer(
      overrides: [
        intelligentModelManagerSnapshotProvider.overrideWith(
          (ref) async => snapshot,
        ),
      ],
    );
    addTearDown(container.dispose);

    await container.read(intelligentModelManagerSnapshotProvider.future);
    final projected = container.read(intelligentModelsListProvider);

    expect(projected.requireValue, [entry]);
  });
}
