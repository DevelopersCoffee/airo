import 'dart:async';

import 'package:feature_mind/src/model_bench/model_bench_controller.dart';
import 'package:feature_mind/src/model_bench/model_bench_display.dart';
import 'package:feature_mind/src/runtime/models/model_models.dart';
import 'package:feature_mind/src/runtime/ports/model_port.dart';
import 'package:flutter_test/flutter_test.dart';

/// Implements the full frozen [ModelPort] surface; only [benchmark] and
/// [thermal] matter to the controller under test, the rest are unused stubs.
class _FakeModelPort implements ModelPort {
  final Map<String, ModelBench> nextBench = {};
  int benchmarkCallCount = 0;
  final _thermal = StreamController<ThermalState>.broadcast();

  void emitThermal(ThermalState state) => _thermal.add(state);

  Future<void> disposeStreams() => _thermal.close();

  @override
  Future<List<MindModel>> all() async => const [];

  @override
  Future<({int usedBytes, int budgetBytes})> storage() async =>
      (usedBytes: 0, budgetBytes: 0);

  @override
  Future<void> load(String modelId) async {}

  @override
  Future<void> unload(String modelId) async {}

  @override
  Stream<({int received, int total})> download(String modelId) =>
      const Stream.empty();

  @override
  Future<ModelBench> benchmark(String modelId) async {
    benchmarkCallCount++;
    final bench = nextBench[modelId];
    if (bench == null) {
      throw StateError('no bench queued for $modelId in this fixture');
    }
    return bench;
  }

  @override
  Stream<ThermalState> thermal() => _thermal.stream;
}

ModelBench _bench({
  ThermalState under = ThermalState.nominal,
  int measuredAtMs = 1000,
}) => ModelBench(
  tokensPerSecond: 24.5,
  firstTokenMs: 420,
  residentBytes: 2600000000,
  batteryPercentPerHour: 9,
  measuredUnder: under,
  measuredAtMs: measuredAtMs,
);

void main() {
  const modelId = 'phi_4_mini';

  group('non-happy states', () {
    test('a model with no bench run yet reports notRun', () {
      final port = _FakeModelPort();
      final controller = ModelBenchController(
        modelPort: port,
        currentDeviceId: () => 'device-a',
      );

      expect(controller.currentDisplay(modelId), ModelBenchDisplay.notRun);
    });

    test('running a benchmark reports inProgress before it resolves', () async {
      final port = _FakeModelPort()..nextBench[modelId] = _bench();
      final controller = ModelBenchController(
        modelPort: port,
        currentDeviceId: () => 'device-a',
      );

      final future = controller.runBenchmark(modelId);
      // Synchronously after the call, before the awaited benchmark()
      // resolves: this is the "in progress" window a surface must render.
      expect(
        controller.currentDisplay(modelId).status,
        ModelBenchStatus.inProgress,
      );

      await future;

      expect(
        controller.currentDisplay(modelId).status,
        ModelBenchStatus.measured,
      );
      expect(controller.currentDisplay(modelId).bench, _bench());
    });
  });

  group('staleness — thermal change', () {
    test('a thermal transition away from the measured state marks it stale '
        'and triggers an automatic re-benchmark', () async {
      final port = _FakeModelPort()
        ..nextBench[modelId] = _bench(under: ThermalState.nominal);
      final controller = ModelBenchController(
        modelPort: port,
        currentDeviceId: () => 'device-a',
      );
      await controller.runBenchmark(modelId);
      controller.startWatchingThermal();

      final events = <ModelBenchDisplay>[];
      final sub = controller.displayFor(modelId).listen(events.add);

      // The re-run measures under the new thermal state.
      port.nextBench[modelId] = _bench(
        under: ThermalState.serious,
        measuredAtMs: 2000,
      );
      port.emitThermal(ThermalState.serious);
      await pumpEventQueue();

      expect(events.first.status, ModelBenchStatus.stale);
      expect(events.first.staleReason, ModelBenchStaleReason.thermalChanged);
      // The old reading is still visible while the re-run is in flight --
      // a surface can caption "last measured under nominal" rather than
      // going blank.
      expect(events.first.bench!.measuredUnder, ThermalState.nominal);

      expect(events.last.status, ModelBenchStatus.measured);
      expect(events.last.bench!.measuredUnder, ThermalState.serious);
      expect(port.benchmarkCallCount, 2);

      await sub.cancel();
    });

    test('a thermal event matching the measured state is a no-op', () async {
      final port = _FakeModelPort()
        ..nextBench[modelId] = _bench(under: ThermalState.nominal);
      final controller = ModelBenchController(
        modelPort: port,
        currentDeviceId: () => 'device-a',
      );
      await controller.runBenchmark(modelId);
      controller.startWatchingThermal();

      port.emitThermal(ThermalState.nominal);
      await pumpEventQueue();

      expect(
        controller.currentDisplay(modelId).status,
        ModelBenchStatus.measured,
      );
      expect(port.benchmarkCallCount, 1);
    });

    test('a thermal event before any benchmark has run is a no-op', () async {
      final port = _FakeModelPort();
      final controller = ModelBenchController(
        modelPort: port,
        currentDeviceId: () => 'device-a',
      );
      controller.startWatchingThermal();

      port.emitThermal(ThermalState.critical);
      await pumpEventQueue();

      expect(controller.currentDisplay(modelId), ModelBenchDisplay.notRun);
      expect(port.benchmarkCallCount, 0);
    });
  });

  group('staleness — device change', () {
    test('a reading measured on a different device is stale', () async {
      final port = _FakeModelPort()..nextBench[modelId] = _bench();
      var deviceId = 'device-a';
      final controller = ModelBenchController(
        modelPort: port,
        currentDeviceId: () => deviceId,
      );
      await controller.runBenchmark(modelId);

      deviceId = 'device-b'; // e.g. an .airobackup restore onto new hardware
      final display = controller.reevaluateStaleness(modelId);

      expect(display.status, ModelBenchStatus.stale);
      expect(display.staleReason, ModelBenchStaleReason.deviceChanged);
    });
  });

  group('staleness — elapsed time', () {
    test('a reading older than the staleness window is stale', () async {
      final port = _FakeModelPort()
        ..nextBench[modelId] = _bench(measuredAtMs: 0);
      var now = 0;
      final controller = ModelBenchController(
        modelPort: port,
        currentDeviceId: () => 'device-a',
        staleAfter: const Duration(hours: 6),
        nowMs: () => now,
      );
      await controller.runBenchmark(modelId);

      now = const Duration(hours: 7).inMilliseconds;
      final display = controller.reevaluateStaleness(modelId);

      expect(display.status, ModelBenchStatus.stale);
      expect(display.staleReason, ModelBenchStaleReason.staleByTime);
    });

    test('a fresh reading on the same device is not disturbed', () async {
      final port = _FakeModelPort()
        ..nextBench[modelId] = _bench(measuredAtMs: 0);
      var now = 0;
      final controller = ModelBenchController(
        modelPort: port,
        currentDeviceId: () => 'device-a',
        staleAfter: const Duration(hours: 6),
        nowMs: () => now,
      );
      await controller.runBenchmark(modelId);

      now = const Duration(hours: 1).inMilliseconds;
      final display = controller.reevaluateStaleness(modelId);

      expect(display.status, ModelBenchStatus.measured);
    });
  });
}
