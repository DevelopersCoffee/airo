import '../runtime/models/model_models.dart';

/// Default warmup / timed counts. Matches `airo_mind_core::BenchProtocol`.
const int kModelBenchWarmupIterations = 3;
const int kModelBenchTimedIterations = 5;

/// Short deterministic prompt used when the engine is asked to bench itself.
/// Not a meeting-secretary prompt — Model Bench is not minutes.
const String kModelBenchPrompt = 'Count from 1 to 8, digits only.';

const int kModelBenchMaxOutputTokens = 16;

/// One timed generate() observation, the Dart shape of Rust `RuntimeStats`.
class GenerationBenchSample {
  const GenerationBenchSample({
    required this.prefillMs,
    required this.prefillTokens,
    required this.generationMs,
    required this.generatedTokens,
    required this.tokensPerSecond,
    required this.peakRssBytes,
  });

  final int prefillMs;
  final int prefillTokens;
  final int generationMs;
  final int generatedTokens;
  final double tokensPerSecond;
  final int peakRssBytes;
}

/// Hardware / engine settings that make a tok/s figure interpretable.
class GenerationBenchMetadata {
  const GenerationBenchMetadata({
    this.backend = InferenceAccelBackend.none,
    this.clockControl = GpuClockControl.unlocked,
    this.gpuLayers = 0,
    this.threadCount = 1,
    this.mode = ModelBenchMode.combined,
  });

  final InferenceAccelBackend backend;
  final GpuClockControl clockControl;
  final int gpuLayers;
  final int threadCount;
  final ModelBenchMode mode;
}

/// Median-reduced result of a warmed generation bench.
class GenerationBenchReport {
  const GenerationBenchReport({
    required this.medianTokensPerSecond,
    required this.medianFirstTokenMs,
    required this.peakRssBytes,
    required this.promptTokens,
    required this.generatedTokens,
    required this.warmupIterations,
    required this.timedIterations,
    required this.metadata,
  });

  final double medianTokensPerSecond;
  final int medianFirstTokenMs;
  final int peakRssBytes;
  final int promptTokens;
  final int generatedTokens;
  final int warmupIterations;
  final int timedIterations;
  final GenerationBenchMetadata metadata;

  ModelBench toModelBench({
    required int residentBytes,
    required ThermalState measuredUnder,
    required int measuredAtMs,
    double batteryPercentPerHour = 0,
  }) => ModelBench(
    tokensPerSecond: medianTokensPerSecond,
    firstTokenMs: medianFirstTokenMs,
    residentBytes: residentBytes,
    batteryPercentPerHour: batteryPercentPerHour,
    measuredUnder: measuredUnder,
    measuredAtMs: measuredAtMs,
    accelBackend: metadata.backend,
    clockControl: metadata.clockControl,
    gpuLayers: metadata.gpuLayers,
    threadCount: metadata.threadCount,
    warmupIterations: warmupIterations,
    timedIterations: timedIterations,
    protocol: metadata.mode,
    promptTokens: promptTokens,
    generatedTokens: generatedTokens,
  );
}

/// Median of [values]. Empty → 0. Even length uses the mean of the two
/// central values, matching `airo_mind_core::median_f64` / Jan's
/// `statistics.median`.
double medianF64(List<double> values) {
  if (values.isEmpty) return 0;
  final sorted = [...values]..sort();
  final n = sorted.length;
  if (n.isOdd) return sorted[n ~/ 2];
  return (sorted[n ~/ 2 - 1] + sorted[n ~/ 2]) / 2.0;
}

/// Median of [values]. Empty → 0. Even length uses truncated mean of the
/// two central values, matching `airo_mind_core::median_u64`.
int medianU64(List<int> values) {
  if (values.isEmpty) return 0;
  final sorted = [...values]..sort();
  final n = sorted.length;
  if (n.isOdd) return sorted[n ~/ 2];
  final a = sorted[n ~/ 2 - 1];
  final b = sorted[n ~/ 2];
  return a ~/ 2 + b ~/ 2 + (a % 2 + b % 2) ~/ 2;
}

/// Maps a platform thermal summary string onto [ThermalState].
///
/// Same four-step ladder as Android `PowerManager` / iOS
/// `ProcessInfo.ThermalState` / `LlmThermalPressure`. Unknown or empty
/// summaries are [ThermalState.nominal], not a guess at heat — they mean
/// the probe did not report pressure.
ThermalState thermalStateFromSummary(String? summary) {
  final text = summary?.toLowerCase().trim() ?? '';
  if (text.contains('critical') || text.contains('shutdown')) {
    return ThermalState.critical;
  }
  if (text.contains('severe') || text.contains('serious')) {
    return ThermalState.serious;
  }
  if (text.contains('moderate') || text.contains('fair')) {
    return ThermalState.fair;
  }
  return ThermalState.nominal;
}

/// Reduce already-timed samples. Warmup must have been discarded by the
/// caller. An empty list throws rather than returning zeros — zeros would
/// look like a real measurement.
GenerationBenchReport aggregateGenerationBench({
  required List<GenerationBenchSample> samples,
  required int warmupIterations,
  required int timedIterations,
  GenerationBenchMetadata metadata = const GenerationBenchMetadata(),
}) {
  if (samples.isEmpty) {
    throw StateError(
      'benchmark produced no timed samples (timedIterations must be > 0)',
    );
  }
  return GenerationBenchReport(
    medianTokensPerSecond: medianF64([
      for (final s in samples) s.tokensPerSecond,
    ]),
    medianFirstTokenMs: medianU64([for (final s in samples) s.prefillMs]),
    peakRssBytes: samples
        .map((s) => s.peakRssBytes)
        .reduce((a, b) => a > b ? a : b),
    promptTokens: samples
        .map((s) => s.prefillTokens)
        .reduce((a, b) => a > b ? a : b),
    generatedTokens: samples
        .map((s) => s.generatedTokens)
        .reduce((a, b) => a > b ? a : b),
    warmupIterations: warmupIterations,
    timedIterations: timedIterations,
    metadata: metadata,
  );
}

/// Runs warmup + timed generate() calls against [sample].
///
/// [sample] is called once per iteration and must itself perform one
/// generate() and return the engine's stats for that call.
Future<GenerationBenchReport> runGenerationBench({
  required Future<GenerationBenchSample> Function() sample,
  int warmupIterations = kModelBenchWarmupIterations,
  int timedIterations = kModelBenchTimedIterations,
  GenerationBenchMetadata metadata = const GenerationBenchMetadata(),
}) async {
  if (timedIterations <= 0) {
    throw StateError(
      'benchmark produced no timed samples (timedIterations must be > 0)',
    );
  }
  for (var i = 0; i < warmupIterations; i++) {
    await sample();
  }
  final samples = <GenerationBenchSample>[
    for (var i = 0; i < timedIterations; i++) await sample(),
  ];
  return aggregateGenerationBench(
    samples: samples,
    warmupIterations: warmupIterations,
    timedIterations: timedIterations,
    metadata: metadata,
  );
}
