import 'dart:io';

import 'package:core_ai/core_ai.dart' as core_ai;
import 'package:feature_mind/feature_mind.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late RustMindRuntime runtime;

  setUp(() => runtime = RustMindRuntime());

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
        isA<MindPortUnavailable>().having(
          (e) => e.port,
          'port',
          'VaultPort',
        ),
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

  test('ports still unimplemented report unavailable, none silently succeed', () async {
    // A port that returned a plausible empty list instead of failing would
    // let a surface render "no devices" when the truth is "not built yet".
    // OperationLogPort uses a Dart fallback when Mind is not initialised (#1213).
    final probes = <String, Future<void>>{
      'vault': runtime.vault.devices(),
      'contexts': runtime.contexts.all(),
      'projections': runtime.projections.states(),
      'mesh': runtime.mesh.authorise(
        const PairingRequest(deviceName: 'x', code: '000000', requestedAtMs: 0),
      ),
      'capabilities': runtime.capabilities.installed(),
      // load/unload/benchmark/thermal, not all/storage/download: those three
      // are real now (#1630) -- see the dedicated group below. load/unload/
      // benchmark/thermal still need the Rust inference engine (#1628,
      // #1638), so they are the honest "still unavailable" probe for models.
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
  });

  test('models.unload/benchmark/thermal still report unavailable', () async {
    await expectLater(
      runtime.models.unload('whatever-model-id'),
      throwsA(isA<MindPortUnavailable>()),
    );
    await expectLater(
      runtime.models.benchmark('whatever-model-id'),
      throwsA(isA<MindPortUnavailable>()),
    );
    await expectLater(
      runtime.models.thermal(),
      emitsError(isA<MindPortUnavailable>()),
    );
  });

  group('models.all/storage/download are real, not stubs (#1630)', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('rust_models_test');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('plugins.flutter.io/path_provider'),
            (MethodCall methodCall) async {
              if (methodCall.method == 'getApplicationDocumentsDirectory') {
                return tempDir.path;
              }
              return null;
            },
          );
    });

    tearDown(() async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('plugins.flutter.io/path_provider'),
            null,
          );
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

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
  });
}
