import 'package:feature_mind/src/model_bench/model_bench_protocol.dart';
import 'package:feature_mind/src/model_bench/speech_bench_protocol.dart';
import 'package:feature_mind/src/runtime/models/model_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SpeechBenchSample.rtf', () {
    test('is wall over audio, and zero duration is 0 not infinity', () {
      expect(
        const SpeechBenchSample(audioDurationMs: 1000, wallMs: 500).rtf,
        0.5,
      );
      expect(const SpeechBenchSample(audioDurationMs: 0, wallMs: 500).rtf, 0);
    });
  });

  group('aggregateSpeechBench', () {
    test('rejects an empty timed set rather than returning zeros', () {
      expect(
        () => aggregateSpeechBench(
          samples: const [],
          warmupIterations: 3,
          timedIterations: 5,
        ),
        throwsStateError,
      );
    });

    test('reports median RTFx and keeps accelerator metadata', () {
      final report = aggregateSpeechBench(
        samples: const [
          SpeechBenchSample(
            audioDurationMs: 1000,
            wallMs: 400,
            peakRssBytes: 1000,
          ),
          SpeechBenchSample(
            audioDurationMs: 1000,
            wallMs: 600,
            peakRssBytes: 2200,
          ),
          SpeechBenchSample(
            audioDurationMs: 1000,
            wallMs: 500,
            peakRssBytes: 1800,
          ),
        ],
        warmupIterations: 1,
        timedIterations: 3,
        metadata: const GenerationBenchMetadata(
          backend: InferenceAccelBackend.metal,
        ),
      );

      expect(report.medianWallMs, 500);
      expect(report.medianRtf, 0.5);
      expect(report.audioDurationMs, 1000);
      expect(report.peakRssBytes, 2200);
      expect(report.metadata.backend, InferenceAccelBackend.metal);
    });
  });

  group('runSpeechBench', () {
    test('discards warmup samples from the median', () async {
      final samples = <SpeechBenchSample>[
        const SpeechBenchSample(audioDurationMs: 1000, wallMs: 900),
        const SpeechBenchSample(audioDurationMs: 1000, wallMs: 400),
        const SpeechBenchSample(audioDurationMs: 1000, wallMs: 500),
        const SpeechBenchSample(audioDurationMs: 1000, wallMs: 600),
      ];
      var i = 0;
      final report = await runSpeechBench(
        sample: () async => samples[i++],
        warmupIterations: 1,
        timedIterations: 3,
      );

      expect(i, 4);
      expect(report.medianWallMs, 500);
      expect(report.medianRtf, 0.5);
    });

    test('zero timed iterations is an error, not a zeroed RTFx', () async {
      await expectLater(
        runSpeechBench(
          sample: () async =>
              const SpeechBenchSample(audioDurationMs: 1000, wallMs: 500),
          warmupIterations: 1,
          timedIterations: 0,
        ),
        throwsStateError,
      );
    });
  });
}
