import 'dart:async';

import '../runtime/models/model_models.dart';
import '../runtime/ports/model_port.dart';
import 'model_bench_display.dart';

/// Drives Model Bench for every model a surface tracks: runs the first
/// measurement, watches [ModelPort.thermal] for transitions and re-measures
/// automatically, and marks a reading stale by device change or elapsed time
/// even when no thermal transition fires.
///
/// MIND-DS-3 (#1456). `ModelPort` is frozen — this controller is built
/// entirely on `benchmark()` and `thermal()`, which the port already
/// declares; nothing here required extending the port.
class ModelBenchController {
  ModelBenchController({
    required ModelPort modelPort,
    required String Function() currentDeviceId,
    this.staleAfter = const Duration(hours: 6),
    int Function()? nowMs,
  }) : _modelPort = modelPort,
       _currentDeviceId = currentDeviceId,
       _nowMs = nowMs ?? _defaultNowMs;

  static int _defaultNowMs() => DateTime.now().millisecondsSinceEpoch;

  final ModelPort _modelPort;
  final String Function() _currentDeviceId;

  /// A reading with no thermal transition and no device change still stops
  /// being trustworthy after this long — battery and thermal state drift
  /// with uptime between discrete transitions.
  final Duration staleAfter;
  final int Function() _nowMs;

  final Map<String, ModelBenchDisplay> _displays = {};
  final Map<String, String> _measuredOnDeviceId = {};
  final Map<String, StreamController<ModelBenchDisplay>> _streams = {};
  StreamSubscription<ThermalState>? _thermalSub;

  /// The current display state for [modelId]. [ModelBenchDisplay.notRun] if
  /// no benchmark has ever started.
  ModelBenchDisplay currentDisplay(String modelId) =>
      _displays[modelId] ?? ModelBenchDisplay.notRun;

  /// A broadcast stream of every display change for [modelId], seeded with
  /// the current state on listen.
  Stream<ModelBenchDisplay> displayFor(String modelId) {
    final controller = _streams.putIfAbsent(
      modelId,
      () => StreamController<ModelBenchDisplay>.broadcast(),
    );
    return controller.stream;
  }

  /// Starts listening for thermal transitions. Call once per controller
  /// lifetime; a transition that changes a measured model's thermal state
  /// away from [ModelBench.measuredUnder] marks it stale and immediately
  /// re-benchmarks it.
  void startWatchingThermal() {
    _thermalSub ??= _modelPort.thermal().listen(_onThermalChanged);
  }

  void _onThermalChanged(ThermalState newState) {
    for (final modelId in _displays.keys.toList(growable: false)) {
      final display = _displays[modelId]!;
      final measuredUnder = display.bench?.measuredUnder;
      if (measuredUnder == null || measuredUnder == newState) continue;
      _emit(
        modelId,
        display.copyWith(
          status: ModelBenchStatus.stale,
          staleReason: ModelBenchStaleReason.thermalChanged,
        ),
      );
      unawaited(runBenchmark(modelId));
    }
  }

  /// Runs (or re-runs) the benchmark for [modelId]. Emits `inProgress`
  /// immediately, then the measured reading once [ModelPort.benchmark]
  /// resolves.
  Future<void> runBenchmark(String modelId) async {
    _emit(
      modelId,
      const ModelBenchDisplay(status: ModelBenchStatus.inProgress),
    );
    final bench = await _modelPort.benchmark(modelId);
    _measuredOnDeviceId[modelId] = _currentDeviceId();
    _emit(
      modelId,
      ModelBenchDisplay(status: ModelBenchStatus.measured, bench: bench),
    );
  }

  /// Re-checks device-change and time-elapsed staleness for [modelId] and
  /// emits an updated display if either fired. Call this on surface entry —
  /// unlike a thermal transition, neither trigger arrives as a push event.
  ///
  /// Returns the (possibly unchanged) current display.
  ModelBenchDisplay reevaluateStaleness(String modelId) {
    final display = _displays[modelId];
    if (display == null || display.status != ModelBenchStatus.measured) {
      return display ?? ModelBenchDisplay.notRun;
    }
    final bench = display.bench!;

    if (_measuredOnDeviceId[modelId] != _currentDeviceId()) {
      return _emit(
        modelId,
        display.copyWith(
          status: ModelBenchStatus.stale,
          staleReason: ModelBenchStaleReason.deviceChanged,
        ),
      );
    }

    final ageMs = _nowMs() - bench.measuredAtMs;
    if (ageMs > staleAfter.inMilliseconds) {
      return _emit(
        modelId,
        display.copyWith(
          status: ModelBenchStatus.stale,
          staleReason: ModelBenchStaleReason.staleByTime,
        ),
      );
    }

    return display;
  }

  ModelBenchDisplay _emit(String modelId, ModelBenchDisplay display) {
    _displays[modelId] = display;
    _streams[modelId]?.add(display);
    return display;
  }

  /// Releases the thermal subscription and every per-model stream.
  void dispose() {
    unawaited(_thermalSub?.cancel());
    _thermalSub = null;
    for (final controller in _streams.values) {
      unawaited(controller.close());
    }
    _streams.clear();
  }
}
