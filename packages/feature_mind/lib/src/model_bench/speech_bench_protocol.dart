import 'model_bench_protocol.dart';

/// Default warmup / timed counts. Matches generation Model Bench.
const int kSpeechBenchWarmupIterations = kModelBenchWarmupIterations;
const int kSpeechBenchTimedIterations = kModelBenchTimedIterations;

/// One timed transcribe() observation.
///
/// RTFx is [rtf] = `wallMs / audioDurationMs` (whisper.cpp's real-time
/// factor). Below 1.0 is faster than real time. Peak RSS stays 0 unless the
/// caller measured it — Dart does not invent a process RSS.
class SpeechBenchSample {
  const SpeechBenchSample({
    required this.audioDurationMs,
    required this.wallMs,
    this.peakRssBytes = 0,
  });

  final int audioDurationMs;
  final int wallMs;
  final int peakRssBytes;

  /// `wallMs / audioDurationMs`. Zero duration → 0, which must not be shown
  /// as a measurement; [runSpeechBench] rejects empty timed sets, and
  /// runners must reject zero-duration clips.
  double get rtf => audioDurationMs == 0 ? 0 : wallMs / audioDurationMs;
}

/// Median-reduced result of a warmed speech bench.
class SpeechBenchReport {
  const SpeechBenchReport({
    required this.medianRtf,
    required this.medianWallMs,
    required this.audioDurationMs,
    required this.peakRssBytes,
    required this.warmupIterations,
    required this.timedIterations,
    required this.metadata,
  });

  final double medianRtf;
  final int medianWallMs;
  final int audioDurationMs;
  final int peakRssBytes;
  final int warmupIterations;
  final int timedIterations;
  final GenerationBenchMetadata metadata;
}

/// Reduce already-timed samples. Warmup must have been discarded by the
/// caller. Empty → throw, never a zero RTFx that looks measured.
SpeechBenchReport aggregateSpeechBench({
  required List<SpeechBenchSample> samples,
  required int warmupIterations,
  required int timedIterations,
  GenerationBenchMetadata metadata = const GenerationBenchMetadata(),
}) {
  if (samples.isEmpty) {
    throw StateError(
      'benchmark produced no timed samples (timedIterations must be > 0)',
    );
  }
  return SpeechBenchReport(
    medianRtf: medianF64([for (final s in samples) s.rtf]),
    medianWallMs: medianU64([for (final s in samples) s.wallMs]),
    audioDurationMs: samples
        .map((s) => s.audioDurationMs)
        .reduce((a, b) => a > b ? a : b),
    peakRssBytes: samples
        .map((s) => s.peakRssBytes)
        .reduce((a, b) => a > b ? a : b),
    warmupIterations: warmupIterations,
    timedIterations: timedIterations,
    metadata: metadata,
  );
}

/// Runs warmup + timed transcribe() calls against [sample].
Future<SpeechBenchReport> runSpeechBench({
  required Future<SpeechBenchSample> Function() sample,
  int warmupIterations = kSpeechBenchWarmupIterations,
  int timedIterations = kSpeechBenchTimedIterations,
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
  final samples = <SpeechBenchSample>[
    for (var i = 0; i < timedIterations; i++) await sample(),
  ];
  return aggregateSpeechBench(
    samples: samples,
    warmupIterations: warmupIterations,
    timedIterations: timedIterations,
    metadata: metadata,
  );
}
