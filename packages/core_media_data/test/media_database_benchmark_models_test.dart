import 'package:core_media_data/core_media_data.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AiroMediaDatabaseBenchmarkPolicy', () {
    const policy = AiroMediaDatabaseBenchmarkPolicy();

    AiroMediaDatabaseBenchmarkPlan plan({
      String planId = 'large-media-db-baseline',
      AiroMediaBenchmarkBudget budget = const AiroMediaBenchmarkBudget(
        maxElapsedMillis: 20000,
        maxPeakMemoryMb: 256,
        maxStorageMb: 512,
        minRowsPerSecond: 1000,
      ),
    }) {
      return AiroMediaDatabaseBenchmarkPlan(
        planId: planId,
        dataset: const AiroMediaBenchmarkDatasetProfile(
          profileId: 'mixed-50k-live-10k-vod-epg',
          kind: AiroMediaBenchmarkDatasetKind.mixedCatalog,
          liveChannelCount: 50000,
          vodItemCount: 10000,
          epgProgramCount: 200000,
          playlistSourceCount: 4,
          metadataFieldCount: 18,
        ),
        steps: const [
          AiroMediaBenchmarkWorkloadStep(
            stepId: 'import-live',
            operation: AiroMediaBenchmarkOperation.importBatch,
            recordCount: 50000,
          ),
          AiroMediaBenchmarkWorkloadStep(
            stepId: 'search-vod',
            operation: AiroMediaBenchmarkOperation.searchText,
            recordCount: 10000,
            queryCount: 250,
          ),
          AiroMediaBenchmarkWorkloadStep(
            stepId: 'compact-epg',
            operation: AiroMediaBenchmarkOperation.snapshotCompactWindow,
            recordCount: 200000,
          ),
        ],
        requiredMetrics: const {
          AiroMediaBenchmarkMetric.elapsedMillis,
          AiroMediaBenchmarkMetric.peakMemoryMb,
          AiroMediaBenchmarkMetric.storageMb,
          AiroMediaBenchmarkMetric.rowsPerSecond,
        },
        budget: budget,
      );
    }

    List<AiroMediaBenchmarkMetricSample> passingSamples() {
      return const [
        AiroMediaBenchmarkMetricSample(
          stepId: 'import-live',
          operation: AiroMediaBenchmarkOperation.importBatch,
          completedRecordCount: 50000,
          elapsedMillis: 8000,
          peakMemoryMb: 180,
          storageMb: 320,
          rowsPerSecond: 6250,
        ),
        AiroMediaBenchmarkMetricSample(
          stepId: 'search-vod',
          operation: AiroMediaBenchmarkOperation.searchText,
          completedRecordCount: 10000,
          elapsedMillis: 2000,
          peakMemoryMb: 192,
          storageMb: 330,
          rowsPerSecond: 5000,
        ),
        AiroMediaBenchmarkMetricSample(
          stepId: 'compact-epg',
          operation: AiroMediaBenchmarkOperation.snapshotCompactWindow,
          completedRecordCount: 200000,
          elapsedMillis: 5000,
          peakMemoryMb: 220,
          storageMb: 420,
          rowsPerSecond: 40000,
        ),
      ];
    }

    test('accepts completed representative media dataset benchmark run', () {
      final run = AiroMediaDatabaseBenchmarkRun(
        planId: 'large-media-db-baseline',
        runnerId: 'drift-adapter-lab',
        samples: passingSamples(),
      );

      final evaluation = policy.evaluate(plan: plan(), run: run);

      expect(evaluation.accepted, isTrue);
    });

    test('rejects missing metrics and incomplete workload', () {
      final run = AiroMediaDatabaseBenchmarkRun(
        planId: 'large-media-db-baseline',
        runnerId: 'fake',
        samples: const [
          AiroMediaBenchmarkMetricSample(
            stepId: 'import-live',
            operation: AiroMediaBenchmarkOperation.importBatch,
            completedRecordCount: 50000,
            elapsedMillis: 8000,
            peakMemoryMb: 180,
            storageMb: 320,
          ),
        ],
      );

      final evaluation = policy.evaluate(plan: plan(), run: run);

      expect(
        evaluation.blockers,
        contains(AiroMediaBenchmarkBlockerCode.missingMetric),
      );
      expect(
        evaluation.blockers,
        contains(AiroMediaBenchmarkBlockerCode.incompleteWorkload),
      );
    });

    test('rejects failed workload and budget overruns', () {
      final run = AiroMediaDatabaseBenchmarkRun(
        planId: 'large-media-db-baseline',
        runnerId: 'fake',
        failedStepIds: const {'compact-epg'},
        samples: const [
          AiroMediaBenchmarkMetricSample(
            stepId: 'import-live',
            operation: AiroMediaBenchmarkOperation.importBatch,
            completedRecordCount: 50000,
            elapsedMillis: 9000,
            peakMemoryMb: 300,
            storageMb: 800,
            rowsPerSecond: 500,
          ),
          AiroMediaBenchmarkMetricSample(
            stepId: 'search-vod',
            operation: AiroMediaBenchmarkOperation.searchText,
            completedRecordCount: 10000,
            elapsedMillis: 9000,
            peakMemoryMb: 290,
            storageMb: 780,
            rowsPerSecond: 800,
          ),
          AiroMediaBenchmarkMetricSample(
            stepId: 'compact-epg',
            operation: AiroMediaBenchmarkOperation.snapshotCompactWindow,
            completedRecordCount: 200000,
            elapsedMillis: 9000,
            peakMemoryMb: 310,
            storageMb: 790,
            rowsPerSecond: 900,
          ),
        ],
      );

      final evaluation = policy.evaluate(plan: plan(), run: run);

      expect(
        evaluation.blockers,
        contains(AiroMediaBenchmarkBlockerCode.failedWorkload),
      );
      expect(
        evaluation.blockers,
        contains(AiroMediaBenchmarkBlockerCode.overTimeBudget),
      );
      expect(
        evaluation.blockers,
        contains(AiroMediaBenchmarkBlockerCode.overMemoryBudget),
      );
      expect(
        evaluation.blockers,
        contains(AiroMediaBenchmarkBlockerCode.overStorageBudget),
      );
      expect(
        evaluation.blockers,
        contains(AiroMediaBenchmarkBlockerCode.belowThroughputFloor),
      );
    });

    test('rejects privacy-unsafe stable ids', () {
      final run = AiroMediaDatabaseBenchmarkRun(
        planId: 'large-media-db-baseline',
        runnerId: 'http://example.com/raw-playlist.m3u',
        samples: passingSamples(),
      );

      final evaluation = policy.evaluate(plan: plan(), run: run);

      expect(
        evaluation.blockers,
        contains(AiroMediaBenchmarkBlockerCode.privacyUnsafeStableId),
      );
    });

    test('diagnostics expose counts and ids without raw media references', () {
      final renderedProfile = plan().dataset.toString();
      final renderedRun = AiroMediaDatabaseBenchmarkRun(
        planId: 'large-media-db-baseline',
        runnerId: 'fake',
        samples: passingSamples(),
      ).toString();

      expect(renderedProfile, contains('mixed-50k-live-10k-vod-epg'));
      expect(renderedProfile, contains('liveChannelCount: 50000'));
      expect(renderedRun, contains('sampleCount: 3'));
      expect(renderedProfile, isNot(contains('http')));
      expect(renderedRun, isNot(contains('/Users/')));
      expect(renderedRun, isNot(contains('credential')));
    });
  });

  group('AiroMediaDatabaseBenchmarkRunner adapters', () {
    final plan = AiroMediaDatabaseBenchmarkPlan(
      planId: 'runner-plan',
      dataset: const AiroMediaBenchmarkDatasetProfile(
        profileId: 'live-10k',
        kind: AiroMediaBenchmarkDatasetKind.liveIptv,
        liveChannelCount: 10000,
        vodItemCount: 0,
        epgProgramCount: 0,
        playlistSourceCount: 1,
        metadataFieldCount: 8,
      ),
      steps: const [
        AiroMediaBenchmarkWorkloadStep(
          stepId: 'import-live',
          operation: AiroMediaBenchmarkOperation.importBatch,
          recordCount: 10000,
        ),
      ],
      requiredMetrics: const {AiroMediaBenchmarkMetric.elapsedMillis},
      budget: const AiroMediaBenchmarkBudget(
        maxElapsedMillis: 5000,
        maxPeakMemoryMb: 128,
        maxStorageMb: 128,
        minRowsPerSecond: 500,
      ),
    );

    test('no-op runner returns an empty run for adapter wiring', () async {
      const runner = AiroNoOpMediaDatabaseBenchmarkRunner();

      final run = await runner.run(plan);

      expect(run.planId, 'runner-plan');
      expect(run.samples, isEmpty);
    });

    test('fake runner returns deterministic samples', () async {
      final runner = AiroFakeMediaDatabaseBenchmarkRunner(
        samples: const [
          AiroMediaBenchmarkMetricSample(
            stepId: 'import-live',
            operation: AiroMediaBenchmarkOperation.importBatch,
            completedRecordCount: 10000,
            elapsedMillis: 1000,
          ),
        ],
      );

      final run = await runner.run(plan);

      expect(run.samples.single.completedRecordCount, 10000);
      expect(run.completedStepIds, {'import-live'});
    });
  });
}
