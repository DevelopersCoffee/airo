import 'package:feature_mind/feature_mind.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
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
    // A surface that only needs the log must be able to tell that the log is
    // the thing missing, not conclude the whole runtime is dead.
    await expectLater(
      runtime.log.count(),
      throwsA(
        isA<MindPortUnavailable>().having(
          (e) => e.port,
          'port',
          'OperationLogPort',
        ),
      ),
    );
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

  test('all eight ports report unavailable, none silently succeeds', () async {
    // A port that returned a plausible empty list instead of failing would
    // let a surface render "no devices" when the truth is "not built yet".
    final probes = <String, Future<void>>{
      'vault': runtime.vault.devices(),
      'log': runtime.log.count(),
      'contexts': runtime.contexts.all(),
      'projections': runtime.projections.states(),
      'mesh': runtime.mesh.authorise(
        const PairingRequest(deviceName: 'x', code: '000000', requestedAtMs: 0),
      ),
      'capabilities': runtime.capabilities.installed(),
      'models': runtime.models.all(),
      'portability': runtime.portability.plan(const []),
    };

    expect(probes.keys.toSet(), MindRuntime.portNames);

    for (final entry in probes.entries) {
      await expectLater(
        entry.value,
        throwsA(isA<MindPortUnavailable>()),
        reason: '${entry.key} resolved instead of reporting unavailable.',
      );
    }
  });
}
