import 'package:feature_mind/src/model_bench/model_bench_protocol.dart';
import 'package:feature_mind/src/runtime/models/model_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('median', () {
    test('f64 odd, even, and empty match the Rust protocol', () {
      expect(medianF64([3, 1, 2]), 2);
      expect(medianF64([4, 1, 2, 3]), 2.5);
      expect(medianF64(const []), 0);
    });

    test('u64 odd, even, and empty match the Rust protocol', () {
      expect(medianU64([30, 10, 20]), 20);
      expect(medianU64([40, 10, 20, 30]), 25);
      expect(medianU64(const []), 0);
    });
  });

  group('thermalStateFromSummary', () {
    test('unknown or empty is nominal, not a guessed heat band', () {
      expect(thermalStateFromSummary(null), ThermalState.nominal);
      expect(thermalStateFromSummary(''), ThermalState.nominal);
      expect(thermalStateFromSummary('none'), ThermalState.nominal);
    });

    test('maps the four-step platform ladder', () {
      expect(thermalStateFromSummary('fair'), ThermalState.fair);
      expect(thermalStateFromSummary('serious'), ThermalState.serious);
      expect(thermalStateFromSummary('critical'), ThermalState.critical);
    });
  });

  group('aggregateGenerationBench', () {
    test('rejects an empty timed set rather than returning zeros', () {
      expect(
        () => aggregateGenerationBench(
          samples: const [],
          warmupIterations: 3,
          timedIterations: 5,
        ),
        throwsStateError,
      );
    });

    test('reports median tok/s and TTFT and keeps CUDA metadata', () {
      final report = aggregateGenerationBench(
        samples: const [
          GenerationBenchSample(
            prefillMs: 120,
            prefillTokens: 8,
            generationMs: 200,
            generatedTokens: 16,
            tokensPerSecond: 22,
            peakRssBytes: 1000,
          ),
          GenerationBenchSample(
            prefillMs: 80,
            prefillTokens: 8,
            generationMs: 200,
            generatedTokens: 16,
            tokensPerSecond: 18,
            peakRssBytes: 1100,
          ),
          GenerationBenchSample(
            prefillMs: 100,
            prefillTokens: 8,
            generationMs: 200,
            generatedTokens: 16,
            tokensPerSecond: 20,
            peakRssBytes: 900,
          ),
        ],
        warmupIterations: 1,
        timedIterations: 3,
        metadata: const GenerationBenchMetadata(
          backend: InferenceAccelBackend.cuda,
          clockControl: GpuClockControl.unlocked,
          gpuLayers: 32,
        ),
      );

      expect(report.medianFirstTokenMs, 100);
      expect(report.medianTokensPerSecond, 20);
      expect(report.peakRssBytes, 1100);
      expect(report.metadata.backend, InferenceAccelBackend.cuda);
      expect(report.metadata.clockControl, GpuClockControl.unlocked);

      final bench = report.toModelBench(
        residentBytes: 2,
        measuredUnder: ThermalState.fair,
        measuredAtMs: 42,
      );
      expect(bench.tokensPerSecond, 20);
      expect(bench.firstTokenMs, 100);
      expect(bench.accelBackend, InferenceAccelBackend.cuda);
      expect(bench.measuredUnder, ThermalState.fair);
      expect(bench.gpuLayers, 32);
      expect(bench.warmupIterations, 1);
      expect(bench.timedIterations, 3);
    });
  });

  group('runGenerationBench', () {
    test('discards warmup samples from the median', () async {
      final samples = <GenerationBenchSample>[
        _sample(prefillMs: 900, tokS: 4),
        _sample(prefillMs: 100, tokS: 20),
        _sample(prefillMs: 120, tokS: 22),
        _sample(prefillMs: 80, tokS: 18),
      ];
      var i = 0;
      final report = await runGenerationBench(
        sample: () async => samples[i++],
        warmupIterations: 1,
        timedIterations: 3,
      );

      expect(i, 4);
      expect(report.medianFirstTokenMs, 100);
      expect(report.medianTokensPerSecond, 20);
    });

    test('zero timed iterations is an error, not a zeroed report', () async {
      await expectLater(
        runGenerationBench(
          sample: () async => _sample(prefillMs: 100, tokS: 20),
          warmupIterations: 1,
          timedIterations: 0,
        ),
        throwsStateError,
      );
    });
  });

  group('productionGenerationBenchMetadata', () {
    test('records unlocked clocks and a single supervisor thread', () {
      final metadata = productionGenerationBenchMetadata();
      expect(metadata.clockControl, GpuClockControl.unlocked);
      expect(metadata.threadCount, 1);
      expect(
        metadata.backend,
        isNot(InferenceAccelBackend.cuda),
        reason: 'CUDA is a named seam, not a default Windows/Linux label',
      );
    });
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
