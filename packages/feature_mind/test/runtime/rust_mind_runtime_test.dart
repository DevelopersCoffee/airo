import 'dart:io';

import 'package:core_ai/core_ai.dart' as core_ai;
import 'package:feature_mind/feature_mind.dart';
import 'package:feature_mind/src/model_bench/generation_bench_runner.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late RustMindRuntime runtime;
  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('rust_mind_runtime_test_');
    Directory(path.join(tempDir.path, 'airo_mind')).createSync(recursive: true);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (MethodCall methodCall) async {
            if (methodCall.method == 'getApplicationSupportDirectory' ||
                methodCall.method == 'getApplicationDocumentsDirectory') {
              return tempDir.path;
            }
            return null;
          },
        );
    runtime = RustMindRuntime();
  });

  tearDown(() async {
    // RustMindRuntime opens the durable op log lazily on construction. Finish
    // that work before deleting the temp support dir or a later test sees a
    // PathNotFoundException from a stale openDefault() future.
    try {
      await runtime.log.count();
    } on Object {
      // Unimplemented Rust ports are irrelevant here; we only need the open.
    }
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          null,
        );
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('every unimplemented method names its port and its issue', () async {
    await expectLater(
      runtime.mesh.push(const DeviceFingerprint('A', 'B', 'C')),
      throwsA(
        isA<MindPortUnavailable>()
            .having((e) => e.port, 'port', 'MeshPort')
            .having((e) => e.reason, 'reason', contains('#')),
      ),
    );
  });

  test('the failure is per port, not per product', () async {
    // A surface that only needs the vault must be able to tell that the vault
    // is the thing missing, not conclude the whole runtime is dead.
    await expectLater(
      runtime.vault.state(),
      throwsA(
        isA<MindPortUnavailable>().having((e) => e.port, 'port', 'VaultPort'),
      ),
    );
  });

  test('streaming methods fail on the stream, not at call time', () async {
    // A surface subscribes and renders an error state. If these threw
    // synchronously the subscription would never form and the surface would
    // crash instead of explaining itself.
    await expectLater(
      runtime.mesh.peers(),
      emitsError(isA<MindPortUnavailable>()),
    );
    await expectLater(
      runtime.projections.rebuild(ProjectionKind.graph),
      emitsError(isA<MindPortUnavailable>()),
    );
    await expectLater(
      runtime.models.download('gemma_3n_e4b'),
      emitsError(isA<MindPortUnavailable>()),
    );
  });

  test(
    'ports still unimplemented report unavailable, none silently succeed',
    () async {
      // A port that returned a plausible empty list instead of failing would
      // let a surface render "no devices" when the truth is "not built yet".
      // OperationLogPort uses a Dart fallback when Mind is not initialised (#1213).
      final probes = <String, Future<void>>{
        'vault': runtime.vault.devices(),
        'contexts': runtime.contexts.all(),
        'projections': runtime.projections.states(),
        'mesh': runtime.mesh.authorise(
          const PairingRequest(
            deviceName: 'x',
            code: '000000',
            requestedAtMs: 0,
          ),
        ),
        'capabilities': runtime.capabilities.installed(),
        // load/unload still need the Rust inference engine (#1628,
        // #1638). benchmark needs a loaded engine (or an injected runner);
        // thermal now probes the device and is real. See the dedicated
        // groups below.
        'models': runtime.models.load('whatever-model-id'),
        'portability': runtime.portability.plan(const []),
      };

      expect(probes.length, MindRuntime.portNames.length - 1);

      for (final entry in probes.entries) {
        await expectLater(
          entry.value,
          throwsA(isA<MindPortUnavailable>()),
          reason: '${entry.key} resolved instead of reporting unavailable.',
        );
      }
    },
  );

  test('models.unload still reports unavailable', () async {
    await expectLater(
      runtime.models.unload('whatever-model-id'),
      throwsA(isA<MindPortUnavailable>()),
    );
  });

  test(
    'models.benchmark without a loaded engine reports unavailable',
    () async {
      await expectLater(
        runtime.models.benchmark('whatever-model-id'),
        throwsA(
          isA<MindPortUnavailable>().having(
            (e) => e.reason,
            'reason',
            contains('not in the catalog'),
          ),
        ),
      );
    },
  );

  test('models.thermal emits a real thermal state, not unavailable', () async {
    await expectLater(runtime.models.thermal(), emits(ThermalState.nominal));
  });

  group('models.all/storage/download are real, not stubs (#1630)', () {
    test('all() reports the default catalog, nothing on disk yet', () async {
      final models = await runtime.models.all();

      expect(models, isNotEmpty);
      expect(models.length, core_ai.ModelCatalog.bundledModels.length);
      expect(
        models.every((m) => m.residency == ModelResidency.available),
        isTrue,
      );
    });

    test('a model downloaded to disk reports as resident', () async {
      // The smallest catalog entry: writing a file matching a multi-GB
      // model's fileSizeBytes here would allocate gigabytes for no reason.
      final catalogModel = core_ai.ModelCatalog.bundledModels.firstWhere(
        (m) => m.id == 'embeddinggemma-300m-tokenizer',
      );
      final modelsDir = Directory(path.join(tempDir.path, 'models'));
      await modelsDir.create(recursive: true);
      await File(
        path.join(modelsDir.path, '${catalogModel.id}.gguf'),
      ).writeAsBytes(List<int>.filled(catalogModel.fileSizeBytes, 0));

      final models = await runtime.models.all();
      final resident = models.firstWhere((m) => m.id == catalogModel.id);

      expect(resident.residency, ModelResidency.resident);
      expect(resident.heldBy, isEmpty);
    });

    test(
      'storage() reports the real on-disk usage against the real quota',
      () async {
        final catalogModel = core_ai.ModelCatalog.bundledModels.first;
        final modelsDir = Directory(path.join(tempDir.path, 'models'));
        await modelsDir.create(recursive: true);
        await File(
          path.join(modelsDir.path, '${catalogModel.id}.gguf'),
        ).writeAsBytes(List<int>.filled(1234, 0));

        final storage = await runtime.models.storage();

        expect(storage.usedBytes, 1234);
        expect(
          storage.budgetBytes,
          core_ai.ModelStorageManager.defaultStorageBudgetBytes,
        );
      },
    );

    test('download() errors on the stream for an id absent from the '
        'catalog, never at call time', () async {
      await expectLater(
        runtime.models.download('not-a-real-model-id'),
        emitsError(isA<MindPortUnavailable>()),
      );
    });

    test(
      'benchmark() runs warmup/median and records CUDA metadata when a runner is injected',
      () async {
        final catalogModel = core_ai.ModelCatalog.bundledModels.firstWhere(
          (m) => m.id == 'embeddinggemma-300m-tokenizer',
        );
        final modelsDir = Directory(path.join(tempDir.path, 'models'));
        await modelsDir.create(recursive: true);
        await File(
          path.join(modelsDir.path, '${catalogModel.id}.gguf'),
        ).writeAsBytes(List<int>.filled(catalogModel.fileSizeBytes, 0));
        await Directory(path.join(tempDir.path, 'airo_mind')).create(recursive: true);
        await File(
          path.join(tempDir.path, 'airo_mind', 'mind_ops.jsonl'),
        ).writeAsString('');

        final benchRuntime = RustMindRuntime(
          warmupIterations: 1,
          timedIterations: 3,
          benchMetadata: const GenerationBenchMetadata(
            backend: InferenceAccelBackend.cuda,
            clockControl: GpuClockControl.unlocked,
            gpuLayers: 32,
            threadCount: 1,
          ),
          readThermal: () async => ThermalState.fair,
          benchRunner: _ScriptedBenchRunner([
            _sample(prefillMs: 900, tokS: 4),
            _sample(prefillMs: 100, tokS: 20),
            _sample(prefillMs: 120, tokS: 22),
            _sample(prefillMs: 80, tokS: 18),
          ]),
        );

        final bench = await benchRuntime.models.benchmark(catalogModel.id);

        expect(bench.tokensPerSecond, 20);
        expect(bench.firstTokenMs, 100);
        expect(bench.accelBackend, InferenceAccelBackend.cuda);
        expect(bench.clockControl, GpuClockControl.unlocked);
        expect(bench.gpuLayers, 32);
        expect(bench.measuredUnder, ThermalState.fair);
        expect(bench.warmupIterations, 1);
        expect(bench.timedIterations, 3);
        expect(bench.residentBytes, catalogModel.fileSizeBytes);
      },
    );
  });
}

GenerationBenchSample _sample({required int prefillMs, required double tokS}) =>
    GenerationBenchSample(
      prefillMs: prefillMs,
      prefillTokens: 8,
      generationMs: 200,
      generatedTokens: 16,
      tokensPerSecond: tokS,
      peakRssBytes: 1000,
    );

class _ScriptedBenchRunner implements GenerationBenchRunner {
  _ScriptedBenchRunner(this._samples);

  final List<GenerationBenchSample> _samples;
  var _i = 0;

  @override
  Future<GenerationBenchSample> sample() async => _samples[_i++];
}
