import 'package:core_ai/core_ai.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ModelPreloader', () {
    late ModelResidencyManager residencyManager;

    setUp(() {
      residencyManager = ModelResidencyManager(
        loadBudgetBytes: () async => 4096,
      );
    });

    test('warms text, then tts, then stt in order', () async {
      final order = <String>[];
      final preloader = ModelPreloader(residencyManager: residencyManager);

      final report = await preloader.preloadSelectedModels(
        adapters: [
          _FakeWarmupAdapter(
            spec: const ModelResidentSpec(
              id: 'stt',
              residentType: ResidentRuntimeType.stt,
              estimatedMemoryBytes: 256,
              sidecar: true,
            ),
            onWarmup: () => order.add('stt'),
          ),
          _FakeWarmupAdapter(
            spec: const ModelResidentSpec(
              id: 'text',
              residentType: ResidentRuntimeType.text,
              estimatedMemoryBytes: 512,
            ),
            onWarmup: () => order.add('text'),
          ),
          _FakeWarmupAdapter(
            spec: const ModelResidentSpec(
              id: 'tts',
              residentType: ResidentRuntimeType.tts,
              estimatedMemoryBytes: 128,
              sidecar: true,
            ),
            onWarmup: () => order.add('tts'),
          ),
        ],
      );

      expect(order, ['text', 'tts', 'stt']);
      expect(
        report.entries.map((entry) => entry.status),
        everyElement(ModelPreloadEntryStatus.warmed),
      );
    });

    test('skips image runtimes during background preload', () async {
      final preloader = ModelPreloader(residencyManager: residencyManager);

      final report = await preloader.preloadSelectedModels(
        adapters: [
          _FakeWarmupAdapter(
            spec: const ModelResidentSpec(
              id: 'image',
              residentType: ResidentRuntimeType.image,
              estimatedMemoryBytes: 1024,
            ),
          ),
        ],
      );

      expect(report.entries.single.status, ModelPreloadEntryStatus.skipped);
      expect(report.entries.single.reason, 'image_models_preload_disabled');
    });

    test('aborts remaining warmups after abortPreload is requested', () async {
      late ModelPreloader preloader;
      final warmed = <String>[];
      preloader = ModelPreloader(residencyManager: residencyManager);

      final report = await preloader.preloadSelectedModels(
        adapters: [
          _FakeWarmupAdapter(
            spec: const ModelResidentSpec(
              id: 'text',
              residentType: ResidentRuntimeType.text,
              estimatedMemoryBytes: 512,
            ),
            onWarmup: () {
              warmed.add('text');
              preloader.abortPreload();
            },
          ),
          _FakeWarmupAdapter(
            spec: const ModelResidentSpec(
              id: 'tts',
              residentType: ResidentRuntimeType.tts,
              estimatedMemoryBytes: 128,
              sidecar: true,
            ),
            onWarmup: () => warmed.add('tts'),
          ),
        ],
      );

      expect(warmed, ['text']);
      expect(report.aborted, isTrue);
      expect(report.entries.last.reason, 'aborted');
    });

    test('stops new warmups when generation becomes active', () async {
      var generationActive = false;
      final warmed = <String>[];
      final preloader = ModelPreloader(
        residencyManager: residencyManager,
        isGenerationActive: () => generationActive,
      );

      final report = await preloader.preloadSelectedModels(
        adapters: [
          _FakeWarmupAdapter(
            spec: const ModelResidentSpec(
              id: 'text',
              residentType: ResidentRuntimeType.text,
              estimatedMemoryBytes: 512,
            ),
            onWarmup: () {
              warmed.add('text');
              generationActive = true;
            },
          ),
          _FakeWarmupAdapter(
            spec: const ModelResidentSpec(
              id: 'stt',
              residentType: ResidentRuntimeType.stt,
              estimatedMemoryBytes: 256,
              sidecar: true,
            ),
            onWarmup: () => warmed.add('stt'),
          ),
        ],
      );

      expect(warmed, ['text']);
      expect(report.aborted, isTrue);
      expect(report.entries.last.reason, 'generation_active');
    });
  });
}

class _FakeWarmupAdapter implements ModelWarmupAdapter {
  _FakeWarmupAdapter({required this.spec, this.onWarmup});

  final ModelResidentSpec spec;
  final void Function()? onWarmup;

  @override
  ModelResidentSpec get residentSpec => spec;

  @override
  Future<bool> isAvailable() async => true;

  @override
  Future<bool> warmup() async {
    onWarmup?.call();
    return true;
  }
}
