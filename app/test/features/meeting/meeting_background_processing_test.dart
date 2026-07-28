import 'package:airo_app/features/meeting/application/services/meeting_background_processor.dart';
import 'package:airo_app/features/meeting/application/services/meeting_intelligence_pipeline.dart';
import 'package:airo_app/features/meeting/application/services/meeting_session_controller.dart';
import 'package:airo_app/features/meeting/domain/entities/meeting_audio_metadata.dart';
import 'package:airo_app/features/meeting/domain/entities/meeting_intelligence.dart';
import 'package:airo_app/features/meeting/domain/entities/meeting_record.dart';
import 'package:airo_app/features/meeting/domain/entities/transcript_chunk.dart';
import 'package:airo_app/features/meeting/infrastructure/storage/in_memory_meeting_repository.dart';
import 'package:feature_meeting_intelligence/feature_meeting_intelligence.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('meeting background processing', () {
    test(
      'completion returns after acceptance and later persists redacted data',
      () async {
        final repository = _TrackingMeetingRepository();
        final summary = _TrackingSummaryProvider();
        final controller = MeetingSessionController(
          repository: repository,
          backgroundProcessor: MeetingBackgroundProcessor(
            repository: repository,
            pipeline: MeetingIntelligencePipeline(),
            coordinator: MeetingIntelligenceCoordinator.inline(
              summaryProvider: summary,
              searchIndexProvider:
                  const DeterministicMeetingSearchIndexProvider(),
              embeddingProvider: const _SuccessfulEmbeddingProvider(),
            ),
          ),
          now: () => DateTime.utc(2026, 7, 28, 12),
        );
        await controller.startMeeting(id: 'meeting-1', title: 'Roadmap sync');
        controller.receiveTranscriptChunk(
          const TranscriptChunk.finalChunk(
            id: 'chunk-1',
            meetingId: 'meeting-1',
            text: 'Call +91 98765 43210. Action: Priya to share launch notes.',
            startMs: 0,
            endMs: 1000,
          ),
        );

        final completed = await controller.completeMeeting(
          audioMetadata: _audio,
        );

        expect(completed.state, MeetingState.completed);
        expect(summary.invocationCount, 0);
        expect(
          await repository.transcriptChunksForMeeting('meeting-1'),
          isEmpty,
        );

        final handle = controller.lastBackgroundJob;
        expect(handle, isNotNull);
        final result = await handle!.completion;

        expect(summary.invocationCount, 1);
        expect(
          result.persistenceState,
          MeetingBackgroundPersistenceState.completed,
        );
        expect(
          result.intelligence
              .outcomeFor(MeetingIntelligenceStage.embedding)
              .state,
          MeetingIntelligenceStageState.completed,
        );
        expect(repository.lastSaved?.embedding?.modelSha256, 'c' * 64);
        expect(repository.lastSaved?.embedding?.values, hasLength(256));
        final chunks = await repository.transcriptChunksForMeeting('meeting-1');
        expect(chunks.single.text, contains('[REDACTED_PHONE]'));
        expect(chunks.single.text, isNot(contains('98765')));
      },
    );

    test(
      'reports repository failure without changing completed stage outcomes',
      () async {
        final repository = _FailingMeetingRepository();
        final processor = MeetingBackgroundProcessor(
          repository: repository,
          pipeline: MeetingIntelligencePipeline(),
          coordinator: const MeetingIntelligenceCoordinator.inline(
            summaryProvider: DeterministicMeetingSummaryProvider(),
            searchIndexProvider: DeterministicMeetingSearchIndexProvider(),
          ),
        );
        final record = MeetingRecord.started(
          id: 'meeting-1',
          title: 'Roadmap sync',
          startedAt: DateTime.utc(2026, 7, 28, 11),
        ).complete(endedAt: DateTime.utc(2026, 7, 28, 12));

        final result = await processor
            .accept(
              record: record,
              audioMetadata: _audio,
              finalChunks: const [
                TranscriptChunk.finalChunk(
                  id: 'chunk-1',
                  meetingId: 'meeting-1',
                  text: 'Action: Keep the failure typed.',
                  startMs: 0,
                  endMs: 1000,
                ),
              ],
            )
            .completion;

        expect(
          result.intelligence
              .outcomeFor(MeetingIntelligenceStage.summary)
              .state,
          MeetingIntelligenceStageState.completed,
        );
        expect(
          result.persistenceState,
          MeetingBackgroundPersistenceState.failed,
        );
        expect(
          result.persistenceCode,
          MeetingBackgroundPersistenceCode.repositoryFailure,
        );
        expect(
          result.toDiagnosticMap().toString(),
          isNot(contains('synthetic')),
        );
      },
    );

    test(
      'default session composition accepts an installed embedding provider',
      () async {
        final repository = _TrackingMeetingRepository();
        final controller = MeetingSessionController(
          repository: repository,
          embeddingProvider: const _SuccessfulEmbeddingProvider(),
          now: () => DateTime.utc(2026, 7, 28, 12),
        );
        await controller.startMeeting(id: 'meeting-1', title: 'Local model');
        controller.receiveTranscriptChunk(
          const TranscriptChunk.finalChunk(
            id: 'chunk-1',
            meetingId: 'meeting-1',
            text: 'Use the approved local model.',
            startMs: 0,
            endMs: 1000,
          ),
        );

        await controller.completeMeeting(audioMetadata: _audio);
        final result = await controller.lastBackgroundJob!.completion;

        expect(
          result.intelligence
              .outcomeFor(MeetingIntelligenceStage.embedding)
              .state,
          MeetingIntelligenceStageState.completed,
        );
        expect(repository.lastSaved?.embedding, isNotNull);
      },
    );

    test('accepted work can be cancelled before its first stage', () async {
      final repository = InMemoryMeetingRepository();
      final processor = MeetingBackgroundProcessor(
        repository: repository,
        pipeline: MeetingIntelligencePipeline(),
        coordinator: const MeetingIntelligenceCoordinator.inline(
          summaryProvider: DeterministicMeetingSummaryProvider(),
          searchIndexProvider: DeterministicMeetingSearchIndexProvider(),
        ),
      );
      final record = MeetingRecord.started(
        id: 'meeting-1',
        title: 'Roadmap sync',
        startedAt: DateTime.utc(2026, 7, 28, 11),
      ).complete(endedAt: DateTime.utc(2026, 7, 28, 12));

      final handle = processor.accept(
        record: record,
        audioMetadata: _audio,
        finalChunks: const [
          TranscriptChunk.finalChunk(
            id: 'chunk-1',
            meetingId: 'meeting-1',
            text: 'Action: Cancel this background job.',
            startMs: 0,
            endMs: 1000,
          ),
        ],
      );
      handle.cancel();
      final result = await handle.completion;

      expect(
        result.intelligence.outcomeFor(MeetingIntelligenceStage.summary).state,
        MeetingIntelligenceStageState.cancelled,
      );
      expect(
        result.persistenceState,
        MeetingBackgroundPersistenceState.skipped,
      );
      expect(await repository.meetingById('meeting-1'), isNull);
    });
  });
}

const _audio = MeetingAudioMetadata(
  meetingId: 'meeting-1',
  filePath: '/private/local/meeting-1.m4a',
  codec: 'm4a',
  sampleRateHz: 16000,
  channelCount: 1,
  sizeBytes: 2048,
  sha256: 'abc123',
);

class _TrackingSummaryProvider implements MeetingSummaryStageProvider {
  int invocationCount = 0;

  @override
  MeetingIntelligenceStage get stage => MeetingIntelligenceStage.summary;

  @override
  MeetingSummaryProjection process(MeetingIntelligenceJobRequest request) {
    invocationCount += 1;
    return const DeterministicMeetingSummaryProvider().process(request);
  }
}

class _FailingMeetingRepository extends InMemoryMeetingRepository {
  @override
  Future<void> saveIntelligence(MeetingIntelligenceDraft draft) {
    throw StateError('synthetic repository details');
  }
}

class _TrackingMeetingRepository extends InMemoryMeetingRepository {
  MeetingIntelligenceDraft? lastSaved;

  @override
  Future<void> saveIntelligence(MeetingIntelligenceDraft draft) async {
    lastSaved = draft;
    await super.saveIntelligence(draft);
  }
}

class _SuccessfulEmbeddingProvider implements MeetingEmbeddingStageProvider {
  const _SuccessfulEmbeddingProvider();

  @override
  MeetingIntelligenceStage get stage => MeetingIntelligenceStage.embedding;

  @override
  Future<MeetingEmbeddingProviderResult> process(
    MeetingIntelligenceJobRequest request,
  ) async {
    return MeetingEmbeddingProviderSuccess(
      projection: MeetingEmbeddingProjection(
        modelId: 'test/minilm',
        revision: 'r1',
        modelSha256: 'c' * 64,
        dimensions: 256,
        values: List.filled(256, 0.5),
      ),
    );
  }
}
