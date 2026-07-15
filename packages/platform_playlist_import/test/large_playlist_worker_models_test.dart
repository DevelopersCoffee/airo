import 'package:flutter_test/flutter_test.dart';
import 'package:platform_playlist_import/platform_playlist_import.dart';

void main() {
  group('AiroLargePlaylistWorkerPolicy', () {
    const policy = AiroLargePlaylistWorkerPolicy();

    AiroLargePlaylistImportPlan plan({
      String jobId = 'large-import-250k',
      int expectedItemCount = 250000,
      int batchSize = 5000,
      int maxConcurrency = 2,
      List<AiroLargePlaylistWorkerStage>? stages,
    }) {
      return AiroLargePlaylistImportPlan(
        jobId: jobId,
        sourceRef: AiroLargePlaylistSourceRef.redacted('user-playlist-primary'),
        expectedItemCount: expectedItemCount,
        batchSize: batchSize,
        maxConcurrency: maxConcurrency,
        stages: stages ?? AiroLargePlaylistWorkerPolicy.requiredStages,
      );
    }

    test('accepts large import plan with required worker stages', () {
      final evaluation = policy.validate(plan());

      expect(evaluation.accepted, isTrue);
      expect(plan().expectedBatchCount, 50);
    });

    test('rejects invalid counts concurrency and missing stages', () {
      final evaluation = policy.validate(
        plan(
          jobId: '',
          expectedItemCount: 0,
          batchSize: 0,
          maxConcurrency: 0,
          stages: const [AiroLargePlaylistWorkerStage.parse],
        ),
      );

      expect(
        evaluation.blockers,
        contains(AiroLargePlaylistWorkerPlanBlockerCode.emptyJobId),
      );
      expect(
        evaluation.blockers,
        contains(
          AiroLargePlaylistWorkerPlanBlockerCode.invalidExpectedItemCount,
        ),
      );
      expect(
        evaluation.blockers,
        contains(AiroLargePlaylistWorkerPlanBlockerCode.invalidBatchSize),
      );
      expect(
        evaluation.blockers,
        contains(AiroLargePlaylistWorkerPlanBlockerCode.invalidConcurrency),
      );
      expect(
        evaluation.blockers,
        contains(AiroLargePlaylistWorkerPlanBlockerCode.missingRequiredStage),
      );
    });

    test('redacted source refs reject raw playlist locations', () {
      expect(
        () => AiroLargePlaylistSourceRef.redacted(
          'https://example.com/private.m3u',
        ),
        throwsArgumentError,
      );
      expect(
        () => AiroLargePlaylistSourceRef.redacted('/Users/me/private.m3u'),
        throwsArgumentError,
      );
      expect(
        () => AiroLargePlaylistSourceRef.redacted('192.168.1.20/private.m3u'),
        throwsArgumentError,
      );
      expect(
        () => AiroLargePlaylistSourceRef.redacted('Basic abc123'),
        throwsArgumentError,
      );
    });
  });

  group('AiroLargePlaylistProgress', () {
    test(
      'reports partial availability and terminal states deterministically',
      () {
        final progress = AiroLargePlaylistProgress(
          jobId: 'large-import-50k',
          stage: AiroLargePlaylistWorkerStage.batchWrite,
          status: AiroLargePlaylistWorkerStatus.partialAvailable,
          expectedItemCount: 50000,
          parsedCount: 50000,
          normalizedCount: 49000,
          dedupedCount: 48000,
          writtenCount: 12000,
          failedCount: 0,
          batchIndex: 3,
          diagnostics: const [
            AiroLargePlaylistImportDiagnostic(
              code: AiroLargePlaylistWorkerDiagnosticCode
                  .partialAvailabilityPublished,
              stage: AiroLargePlaylistWorkerStage.batchWrite,
            ),
          ],
        );

        expect(progress.completionRatio, 0.24);
        expect(progress.hasPartialAvailability, isTrue);
        expect(progress.isTerminal, isFalse);
        expect(progress.toString(), isNot(contains('http')));
        expect(progress.toString(), isNot(contains('/Users/')));
      },
    );
  });

  group('AiroPlaylistBatchWriter adapters', () {
    test('fake writer accepts all records by default', () async {
      const writer = AiroFakePlaylistBatchWriter();

      final result = await writer.writeBatch(
        const AiroPlaylistBatchWriteRequest(
          jobId: 'large-import-10k',
          batchIndex: 1,
          recordCount: 1000,
        ),
      );

      expect(result.acceptedCount, 1000);
      expect(result.rejectedCount, 0);
      expect(result.isSuccessful, isTrue);
    });

    test(
      'no-op writer rejects records without persistence side effects',
      () async {
        const writer = AiroNoOpPlaylistBatchWriter();

        final result = await writer.writeBatch(
          const AiroPlaylistBatchWriteRequest(
            jobId: 'large-import-10k',
            batchIndex: 1,
            recordCount: 1000,
          ),
        );

        expect(result.acceptedCount, 0);
        expect(result.rejectedCount, 1000);
        expect(result.isSuccessful, isFalse);
      },
    );
  });

  group('AiroLargePlaylistWorker adapters', () {
    test('fake worker emits deterministic progress events', () async {
      final plan = AiroLargePlaylistImportPlan(
        jobId: 'large-import-10k',
        sourceRef: AiroLargePlaylistSourceRef.redacted('user-playlist-primary'),
        expectedItemCount: 10000,
        batchSize: 1000,
        maxConcurrency: 1,
        stages: AiroLargePlaylistWorkerPolicy.requiredStages,
      );
      final worker = AiroFakeLargePlaylistWorker(
        progress: [
          AiroLargePlaylistProgress(
            jobId: 'large-import-10k',
            stage: AiroLargePlaylistWorkerStage.parse,
            status: AiroLargePlaylistWorkerStatus.running,
            expectedItemCount: 10000,
            parsedCount: 1000,
            normalizedCount: 0,
            dedupedCount: 0,
            writtenCount: 0,
            failedCount: 0,
            batchIndex: 0,
          ),
          AiroLargePlaylistProgress(
            jobId: 'large-import-10k',
            stage: AiroLargePlaylistWorkerStage.finalize,
            status: AiroLargePlaylistWorkerStatus.completed,
            expectedItemCount: 10000,
            parsedCount: 10000,
            normalizedCount: 9800,
            dedupedCount: 9700,
            writtenCount: 9700,
            failedCount: 0,
            batchIndex: 10,
          ),
        ],
      );

      final events = await worker.run(plan).toList();

      expect(events, hasLength(2));
      expect(events.last.isTerminal, isTrue);
      expect(events.last.writtenCount, 9700);
    });

    test(
      'fake worker emits cancelled event when cancellation is requested',
      () async {
        final plan = AiroLargePlaylistImportPlan(
          jobId: 'large-import-10k',
          sourceRef: AiroLargePlaylistSourceRef.redacted(
            'user-playlist-primary',
          ),
          expectedItemCount: 10000,
          batchSize: 1000,
          maxConcurrency: 1,
          stages: AiroLargePlaylistWorkerPolicy.requiredStages,
        );
        final worker = AiroFakeLargePlaylistWorker(
          progress: [
            AiroLargePlaylistProgress(
              jobId: 'large-import-10k',
              stage: AiroLargePlaylistWorkerStage.batchWrite,
              status: AiroLargePlaylistWorkerStatus.running,
              expectedItemCount: 10000,
              parsedCount: 5000,
              normalizedCount: 5000,
              dedupedCount: 4900,
              writtenCount: 4000,
              failedCount: 0,
              batchIndex: 4,
            ),
          ],
        );

        await worker.cancel('large-import-10k');
        final events = await worker.run(plan).toList();

        expect(events.single.status, AiroLargePlaylistWorkerStatus.cancelled);
        expect(
          events.single.diagnostics.single.code,
          AiroLargePlaylistWorkerDiagnosticCode.cancellationRequested,
        );
      },
    );
  });
}
