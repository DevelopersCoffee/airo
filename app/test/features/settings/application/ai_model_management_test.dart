import 'package:airo_app/features/settings/application/ai_model_management.dart';
import 'package:core_ai/core_ai.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('modelRegistryProvider', () {
    test(
      'hydrates downloaded models from existing litert artifact paths',
      () async {
        final container = ProviderContainer(
          overrides: [
            modelDownloadServiceProvider.overrideWithValue(
              _FakeModelDownloadService({
                'gemma-4-e2b-it-litertlm':
                    '/models/gemma-4-e2b-it-litertlm.litertlm',
              }),
            ),
          ],
        );
        addTearDown(container.dispose);

        final registry = container.read(modelRegistryProvider);

        await Future<void>.delayed(Duration.zero);

        expect(
          registry.downloadedModels.map((model) => model.id),
          contains('gemma-4-e2b-it-litertlm'),
        );
      },
    );

    test(
      'hydrates legacy gguf paths so existing devices remain visible',
      () async {
        final container = ProviderContainer(
          overrides: [
            modelDownloadServiceProvider.overrideWithValue(
              _FakeModelDownloadService({
                'gemma-4-e2b-it-litertlm':
                    '/models/gemma-4-e2b-it-litertlm.gguf',
              }),
            ),
          ],
        );
        addTearDown(container.dispose);

        final registry = container.read(modelRegistryProvider);

        await Future<void>.delayed(Duration.zero);

        final hydrated = registry.downloadedModels.firstWhere(
          (model) => model.id == 'gemma-4-e2b-it-litertlm',
        );
        expect(hydrated.filePath, '/models/gemma-4-e2b-it-litertlm.gguf');
      },
    );

    test('keeps models absent when no on-disk path exists', () async {
      final container = ProviderContainer(
        overrides: [
          modelDownloadServiceProvider.overrideWithValue(
            _FakeModelDownloadService(const {}),
          ),
        ],
      );
      addTearDown(container.dispose);

      final registry = container.read(modelRegistryProvider);

      await Future<void>.delayed(Duration.zero);

      expect(
        registry.downloadedModels.any(
          (model) => model.id == 'gemma-4-e2b-it-litertlm',
        ),
        isFalse,
      );
    });
  });
}

class _FakeModelDownloadService extends ModelDownloadService {
  _FakeModelDownloadService(this.paths);

  final Map<String, String> paths;

  @override
  Future<String?> resolveExistingModelPath(
    String modelId, {
    OfflineModelInfo? model,
  }) async {
    return paths[modelId];
  }
}
