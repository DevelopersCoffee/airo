import 'dart:io';

import 'package:airo_app/core/mind/mind_model_catalog.dart';
import 'package:airo_app/core/mind/mind_model_sources.dart';
import 'package:airo_app/features/settings/application/ai_model_management.dart';
import 'package:core_ai/core_ai.dart';
import 'package:feature_mind/feature_mind.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

/// The two models `airo_mind_core::models` pins, at plausible sizes. The real
/// values come over the Rust bridge, which a `flutter test` process has no
/// library for — the point under test is that whatever the bridge says is what
/// the registry shows, not what those numbers happen to be.
const _whisper = RequiredModel(
  fileName: 'ggml-tiny.en.bin',
  sizeBytes: 77691713,
  sha256: 'aa1c4b1e1b2c3d4e5f60718293a4b5c6d7e8f90112233445566778899aabbccdd',
);
const _qwen = RequiredModel(
  fileName: 'qwen2.5-0.5b-instruct-q4_k_m.gguf',
  sizeBytes: 491666560,
  sha256: 'bb2d5c2f2c3d4e5f60718293a4b5c6d7e8f90112233445566778899aabbccddee',
);

/// A download service that has never installed anything, so the bundled
/// catalog hydration is a no-op and the scribe entries are what is left to
/// assert. `noSuchMethod` covers the rest of the surface: this test only ever
/// reaches the one method [hydrateDownloadedModels] calls first.
class _EmptyDownloadService implements ModelDownloadService {
  @override
  Future<bool> isModelDownloaded(
    String modelId, {
    OfflineModelInfo? model,
  }) async => false;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory modelsDir;

  setUp(() {
    modelsDir = Directory.systemTemp.createTempSync('airo_mind_models');
  });

  tearDown(() {
    if (modelsDir.existsSync()) modelsDir.deleteSync(recursive: true);
  });

  void writeModel(RequiredModel model, {int? bytes}) {
    File(
      p.join(modelsDir.path, model.fileName),
    ).writeAsBytesSync(List<int>.filled(bytes ?? model.sizeBytes, 0));
  }

  group('hydrateMindScribeModels', () {
    test(
      'registers every pinned model, tagged and priced from the pin',
      () async {
        final registry = ModelRegistry();
        addTearDown(registry.dispose);

        await hydrateMindScribeModels(
          registry,
          requiredModels: () async => [_whisper, _qwen],
          modelsDirectory: () async => modelsDir,
        );

        final whisper = registry.getModel('mind-scribe-whisper-tiny-en');
        final qwen = registry.getModel('mind-scribe-qwen2.5-0.5b-instruct');
        expect(whisper, isNotNull);
        expect(qwen, isNotNull);

        expect(whisper!.family, ModelFamily.other);
        expect(whisper.fileSizeBytes, _whisper.sizeBytes);
        expect(whisper.sha256, _whisper.sha256);
        expect(whisper.tags, contains(mindScribeModelTag));
        expect(whisper.description, contains('Scribe'));
        expect(
          whisper.downloadUrl,
          mindModelDownloadUrls['ggml-tiny.en.bin'],
          reason: 'the shell owns hosting; the entry must not restate it',
        );

        expect(qwen!.family, ModelFamily.qwen);
        expect(qwen.fileSizeBytes, _qwen.sizeBytes);
        expect(qwen.sha256, _qwen.sha256);
        expect(qwen.tags, contains(mindScribeModelTag));
      },
    );

    test('reports not installed when the files are absent', () async {
      final registry = ModelRegistry();
      addTearDown(registry.dispose);

      await hydrateMindScribeModels(
        registry,
        requiredModels: () async => [_whisper, _qwen],
        modelsDirectory: () async => modelsDir,
      );

      expect(registry.downloadedModels, isEmpty);
      expect(
        registry.getModel('mind-scribe-whisper-tiny-en')!.filePath,
        isNull,
      );
    });

    test('reports installed only for files at their pinned size', () async {
      writeModel(_whisper);
      // A half-written download. Reporting this as installed is how "the app
      // says it has the model but cannot transcribe" happens.
      writeModel(_qwen, bytes: 1024);
      final registry = ModelRegistry();
      addTearDown(registry.dispose);

      await hydrateMindScribeModels(
        registry,
        requiredModels: () async => [_whisper, _qwen],
        modelsDirectory: () async => modelsDir,
      );

      expect(
        registry.getModel('mind-scribe-whisper-tiny-en')!.filePath,
        p.join(modelsDir.path, _whisper.fileName),
      );
      expect(
        registry.getModel('mind-scribe-qwen2.5-0.5b-instruct')!.filePath,
        isNull,
      );
    });

    test(
      'registers a named row for a pinned model it has no copy for',
      () async {
        const unknown = RequiredModel(
          fileName: 'future-model.gguf',
          sizeBytes: 42,
          sha256: 'cc',
        );
        final registry = ModelRegistry();
        addTearDown(registry.dispose);

        await hydrateMindScribeModels(
          registry,
          requiredModels: () async => [unknown],
          modelsDirectory: () async => modelsDir,
        );

        final entry = registry.getModel('mind-scribe-future-model.gguf');
        expect(entry, isNotNull);
        expect(entry!.name, 'future-model.gguf');
        expect(entry.tags, contains(mindScribeModelTag));
      },
    );

    test(
      'leaves the registry alone when the pinned list is unreachable',
      () async {
        final registry = ModelRegistry();
        addTearDown(registry.dispose);

        await hydrateMindScribeModels(
          registry,
          requiredModels: () async => throw StateError('bridge missing'),
          modelsDirectory: () async => modelsDir,
        );

        expect(registry.allModels, isEmpty);
      },
    );

    test(
      'still lists the models when the directory cannot be resolved',
      () async {
        final registry = ModelRegistry();
        addTearDown(registry.dispose);

        await hydrateMindScribeModels(
          registry,
          requiredModels: () async => [_whisper],
          modelsDirectory: () async => throw StateError('no path_provider'),
        );

        expect(
          registry.getModel('mind-scribe-whisper-tiny-en')!.filePath,
          isNull,
        );
      },
    );
  });

  group('mindModelRegistryOverrides', () {
    test(
      'serves the shared catalog and the scribe models from one registry',
      () async {
        writeModel(_whisper);
        final container = ProviderContainer(
          overrides: [
            modelDownloadServiceProvider.overrideWithValue(
              _EmptyDownloadService(),
            ),
            ...mindModelRegistryOverrides(
              modelsDirectory: () async => modelsDir,
              requiredModels: () async => [_whisper, _qwen],
            ),
          ],
        );
        addTearDown(container.dispose);

        final registry = container.read(modelRegistryProvider);
        // Hydration is deliberately not awaited by the provider — opening a
        // settings screen must not block on disk. Let it land.
        await Future<void>.delayed(Duration.zero);

        for (final bundled in ModelCatalog.bundledModels) {
          expect(registry.hasModel(bundled.id), isTrue);
        }
        expect(registry.hasModel('mind-scribe-whisper-tiny-en'), isTrue);
        expect(registry.hasModel('mind-scribe-qwen2.5-0.5b-instruct'), isTrue);
        expect(
          registry.getModel('mind-scribe-whisper-tiny-en')!.isDownloaded,
          isTrue,
        );
        expect(
          registry.getModel('mind-scribe-qwen2.5-0.5b-instruct')!.isDownloaded,
          isFalse,
        );
        expect(
          ModelCatalog.bundledModels.any(
            (model) => model.tags.contains(mindScribeModelTag),
          ),
          isFalse,
          reason: 'the shared catalog stays free of scribe models',
        );
      },
    );
  });
}
