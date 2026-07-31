import 'dart:async';

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

    test(
      'does not expose an artifact that fails integrity verification',
      () async {
        final container = ProviderContainer(
          overrides: [
            modelDownloadServiceProvider.overrideWithValue(
              _FakeModelDownloadService(
                const {
                  'gemma-4-e2b-it-litertlm':
                      '/models/gemma-4-e2b-it-litertlm.litertlm',
                },
                invalidIds: {'gemma-4-e2b-it-litertlm'},
              ),
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
      },
    );
  });

  group('activeDownloadsProvider', () {
    test('marks a completed verified download as installed', () async {
      final service = _FakeModelDownloadService({
        'gemma-4-e2b-it-litertlm': '/models/gemma-4-e2b-it.litertlm',
      });
      final container = ProviderContainer(
        overrides: [modelDownloadServiceProvider.overrideWithValue(service)],
      );
      addTearDown(container.dispose);

      container.read(activeDownloadsProvider.notifier);
      service.emit(
        const ModelDownloadProgress(
          modelId: 'gemma-4-e2b-it-litertlm',
          totalBytes: 100,
          downloadedBytes: 100,
          status: ModelDownloadStatus.completed,
        ),
      );
      await Future<void>.delayed(Duration.zero);

      expect(
        container
            .read(modelRegistryProvider)
            .downloadedModels
            .map((model) => model.id),
        contains('gemma-4-e2b-it-litertlm'),
      );
      expect(
        container
            .read(activeDownloadsProvider)['gemma-4-e2b-it-litertlm']
            ?.isComplete,
        isTrue,
      );
    });

    test(
      'download controls delegate to the durable download service',
      () async {
        final service = _FakeModelDownloadService(const {});
        final container = ProviderContainer(
          overrides: [modelDownloadServiceProvider.overrideWithValue(service)],
        );
        addTearDown(container.dispose);

        final notifier = container.read(activeDownloadsProvider.notifier);
        final model = ModelCatalog.bundledModels.first;

        notifier.startDownload(model);
        await notifier.pauseDownload(model.id);
        await notifier.resumeDownload(model.id);
        await notifier.retryDownload(model.id);
        await notifier.cancelDownload(model.id);

        expect(service.calls, [
          'download:${model.id}',
          'pause:${model.id}',
          'resume:${model.id}',
          'retry:${model.id}',
          'cancel:${model.id}',
        ]);
      },
    );
  });
}

class _FakeModelDownloadService implements ModelDownloadService {
  _FakeModelDownloadService(this.paths, {this.invalidIds = const {}});

  final Map<String, String> paths;
  final Set<String> invalidIds;
  final List<String> calls = [];
  final _controller = StreamController<ModelDownloadProgress>.broadcast();

  void emit(ModelDownloadProgress progress) => _controller.add(progress);

  @override
  Stream<ModelDownloadProgress> get globalProgressStream => _controller.stream;

  @override
  Future<List<ModelDownloadProgress>> restoreQueue({
    Iterable<OfflineModelInfo> catalogModels = const [],
  }) async => const [];

  @override
  Stream<ModelDownloadProgress> downloadModel(OfflineModelInfo model) {
    calls.add('download:${model.id}');
    return const Stream<ModelDownloadProgress>.empty();
  }

  @override
  Future<void> pauseDownload(String modelId) async {
    calls.add('pause:$modelId');
  }

  @override
  Future<void> resumeDownload(String modelId) async {
    calls.add('resume:$modelId');
  }

  @override
  Future<void> retryDownload(String modelId, {OfflineModelInfo? model}) async {
    calls.add('retry:$modelId');
  }

  @override
  Future<void> cancelDownload(String modelId) async {
    calls.add('cancel:$modelId');
  }

  @override
  Future<bool> isModelDownloaded(
    String modelId, {
    OfflineModelInfo? model,
  }) async => paths.containsKey(modelId) && !invalidIds.contains(modelId);

  @override
  Future<String?> resolveExistingModelPath(
    String modelId, {
    OfflineModelInfo? model,
  }) async {
    return paths[modelId];
  }

  @override
  Future<String> getModelPath(String modelId, {OfflineModelInfo? model}) async {
    return paths[modelId] ?? '/models/$modelId';
  }

  @override
  Future<void> dispose() async {
    await _controller.close();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
