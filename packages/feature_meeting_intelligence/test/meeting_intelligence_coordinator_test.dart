import 'package:feature_meeting_intelligence/feature_meeting_intelligence.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:platform_worker_jobs/platform_worker_jobs.dart';

void main() {
  group('MeetingIntelligenceCoordinator', () {
    test(
      'reports progress and completes summary and search independently',
      () async {
        final progress = <String>[];
        const coordinator = MeetingIntelligenceCoordinator(
          executor: AiroWorkerExecutor(),
          summaryProvider: DeterministicMeetingSummaryProvider(),
          searchIndexProvider: DeterministicMeetingSearchIndexProvider(),
        );

        final result = await coordinator.run(
          _request(),
          onProgress: (snapshot) {
            progress.add(
              '${snapshot.stage.stableId}:${snapshot.state.stableId}',
            );
          },
        );

        expect(
          result.outcomeFor(MeetingIntelligenceStage.summary).state,
          MeetingIntelligenceStageState.completed,
        );
        expect(
          result.outcomeFor(MeetingIntelligenceStage.searchIndexing).state,
          MeetingIntelligenceStageState.completed,
        );
        expect(result.summary, isNotNull);
        expect(
          result.searchIndex?.searchableText,
          contains('[REDACTED_PHONE]'),
        );
        expect(progress, [
          'summary:queued',
          'search_indexing:queued',
          'summary:running',
          'summary:completed',
          'search_indexing:running',
          'search_indexing:completed',
        ]);
      },
    );

    test('keeps index success when summary provider fails', () async {
      const coordinator = MeetingIntelligenceCoordinator(
        executor: AiroWorkerExecutor(forceInline: true),
        summaryProvider: _ThrowingSummaryProvider(),
        searchIndexProvider: DeterministicMeetingSearchIndexProvider(),
      );

      final result = await coordinator.run(_request());

      expect(
        result.outcomeFor(MeetingIntelligenceStage.summary).code,
        MeetingIntelligenceOutcomeCode.workerFailure,
      );
      expect(
        result.outcomeFor(MeetingIntelligenceStage.searchIndexing).state,
        MeetingIntelligenceStageState.completed,
      );
      expect(result.summary, isNull);
      expect(result.searchIndex, isNotNull);
    });

    test('reports missing providers as unavailable', () async {
      const coordinator = MeetingIntelligenceCoordinator(
        executor: AiroWorkerExecutor(forceInline: true),
      );

      final result = await coordinator.run(
        _request(stages: MeetingIntelligenceStage.values.toSet()),
      );

      for (final stage in MeetingIntelligenceStage.values) {
        expect(
          result.outcomeFor(stage).state,
          MeetingIntelligenceStageState.unavailable,
          reason: stage.stableId,
        );
      }
    });

    test('cancels later work at the next deterministic checkpoint', () async {
      final cancellation = MeetingIntelligenceCancellationToken();
      final search = _TrackingSearchIndexProvider();
      final coordinator = MeetingIntelligenceCoordinator(
        executor: const AiroWorkerExecutor(forceInline: true),
        summaryProvider: _CancellingSummaryProvider(cancellation),
        searchIndexProvider: search,
      );

      final result = await coordinator.run(
        _request(),
        cancellation: cancellation,
      );

      expect(
        result.outcomeFor(MeetingIntelligenceStage.summary).state,
        MeetingIntelligenceStageState.completed,
      );
      expect(
        result.outcomeFor(MeetingIntelligenceStage.searchIndexing).state,
        MeetingIntelligenceStageState.cancelled,
      );
      expect(search.invocationCount, 0);
    });
  });
}

MeetingIntelligenceJobRequest _request({
  Set<MeetingIntelligenceStage> stages = const {
    MeetingIntelligenceStage.summary,
    MeetingIntelligenceStage.searchIndexing,
  },
}) {
  return MeetingIntelligenceJobRequest(
    jobId: 'job-1',
    meetingId: 'meeting-1',
    stages: stages,
    redactedTranscriptSegments: const [
      'Call [REDACTED_PHONE] about the budget risk.',
      'Action: Priya to share launch notes.',
    ],
  );
}

class _ThrowingSummaryProvider implements MeetingSummaryStageProvider {
  const _ThrowingSummaryProvider();

  @override
  MeetingIntelligenceStage get stage => MeetingIntelligenceStage.summary;

  @override
  MeetingSummaryProjection process(MeetingIntelligenceJobRequest request) {
    throw StateError('synthetic worker failure');
  }
}

class _CancellingSummaryProvider implements MeetingSummaryStageProvider {
  const _CancellingSummaryProvider(this.cancellation);

  final MeetingIntelligenceCancellationToken cancellation;

  @override
  MeetingIntelligenceStage get stage => MeetingIntelligenceStage.summary;

  @override
  MeetingSummaryProjection process(MeetingIntelligenceJobRequest request) {
    cancellation.cancel();
    return const DeterministicMeetingSummaryProvider().process(request);
  }
}

class _TrackingSearchIndexProvider implements MeetingSearchIndexStageProvider {
  int invocationCount = 0;

  @override
  MeetingIntelligenceStage get stage => MeetingIntelligenceStage.searchIndexing;

  @override
  MeetingSearchIndexProjection process(MeetingIntelligenceJobRequest request) {
    invocationCount += 1;
    return const DeterministicMeetingSearchIndexProvider().process(request);
  }
}
