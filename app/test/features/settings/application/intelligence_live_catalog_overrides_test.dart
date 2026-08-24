import 'package:airo_app/features/settings/application/ai_model_management.dart';
import 'package:core_ai/core_ai.dart';
import 'package:feature_mind/feature_mind.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('intelligenceLiveCatalogOverrides mirrors the model registry', () {
    final registry = ModelRegistry();
    addTearDown(registry.dispose);
    registry.registerModel(
      const OfflineModelInfo(
        id: 'catalog-model',
        name: 'Catalog model',
        family: ModelFamily.qwen,
        fileSizeBytes: 1024,
        provider: AIProvider.custom,
      ),
    );

    final container = ProviderContainer(
      overrides: [
        modelRegistryProvider.overrideWithValue(registry),
        ...intelligenceLiveCatalogOverrides(),
      ],
    );
    addTearDown(container.dispose);

    expect(container.read(intelligenceCatalogProvider), registry.allModels);
  });
}
