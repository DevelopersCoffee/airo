import 'package:feature_meeting_intelligence/feature_meeting_intelligence.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:platform_worker_jobs/platform_worker_jobs.dart';

void main() {
  group('meeting intelligence contracts', () {
    test('request snapshots its redacted, sendable input', () {
      final stages = <MeetingIntelligenceStage>{
        MeetingIntelligenceStage.summary,
      };
      final segments = <String>['redacted transcript'];
      final request = MeetingIntelligenceJobRequest(
        jobId: 'job-1',
        meetingId: 'meeting-1',
        stages: stages,
        redactedTranscriptSegments: segments,
      );

      stages.add(MeetingIntelligenceStage.embedding);
      segments.add('late mutation');

      expect(request.stages, {MeetingIntelligenceStage.summary});
      expect(request.redactedTranscriptSegments, ['redacted transcript']);
      expect(
        () => request.stages.add(MeetingIntelligenceStage.searchIndexing),
        throwsUnsupportedError,
      );
    });

    test('maps every stage to a stable worker kind', () {
      expect(
        {
          for (final stage in MeetingIntelligenceStage.values)
            stage: stage.workerJobKind,
        },
        {
          MeetingIntelligenceStage.summary: AiroWorkerJobKind.meetingSummary,
          MeetingIntelligenceStage.searchIndexing:
              AiroWorkerJobKind.meetingSearchIndexing,
          MeetingIntelligenceStage.embedding:
              AiroWorkerJobKind.meetingEmbedding,
          MeetingIntelligenceStage.speakerClustering:
              AiroWorkerJobKind.meetingSpeakerClustering,
          MeetingIntelligenceStage.memoryUpdate:
              AiroWorkerJobKind.meetingMemoryUpdate,
        },
      );
    });

    test('reports an unavailable provider without private payloads', () {
      const outcome = MeetingIntelligenceStageOutcome.unavailable(
        stage: MeetingIntelligenceStage.embedding,
      );

      expect(outcome.state, MeetingIntelligenceStageState.unavailable);
      expect(outcome.code, MeetingIntelligenceOutcomeCode.providerUnavailable);
      expect(outcome.toDiagnosticMap(), {
        'stage': 'embedding',
        'state': 'unavailable',
        'code': 'provider_unavailable',
      });
    });

    test('rejects a success code for a failed outcome', () {
      expect(
        () => MeetingIntelligenceStageOutcome.failed(
          stage: MeetingIntelligenceStage.summary,
          code: MeetingIntelligenceOutcomeCode.completed,
        ),
        throwsArgumentError,
      );
    });

    test('cancellation is observable between stages', () {
      final cancellation = MeetingIntelligenceCancellationToken();

      expect(cancellation.isCancelled, isFalse);
      cancellation.cancel();
      expect(cancellation.isCancelled, isTrue);
    });
  });
}
