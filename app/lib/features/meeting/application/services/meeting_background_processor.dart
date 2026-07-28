import 'package:feature_meeting_intelligence/feature_meeting_intelligence.dart';

import '../../domain/entities/meeting_audio_metadata.dart';
import '../../domain/entities/meeting_record.dart';
import '../../domain/entities/transcript_chunk.dart';
import '../../domain/repositories/meeting_repository.dart';
import 'meeting_intelligence_pipeline.dart';

enum MeetingBackgroundPersistenceState {
  completed('completed'),
  skipped('skipped'),
  failed('failed');

  const MeetingBackgroundPersistenceState(this.stableId);

  final String stableId;
}

enum MeetingBackgroundPersistenceCode {
  completed('completed'),
  stageIncomplete('stage_incomplete'),
  repositoryFailure('repository_failure');

  const MeetingBackgroundPersistenceCode(this.stableId);

  final String stableId;
}

class MeetingBackgroundProcessingResult {
  const MeetingBackgroundProcessingResult({
    required this.intelligence,
    required this.persistenceState,
    required this.persistenceCode,
  });

  final MeetingIntelligenceJobResult intelligence;
  final MeetingBackgroundPersistenceState persistenceState;
  final MeetingBackgroundPersistenceCode persistenceCode;

  Map<String, Object> toDiagnosticMap() => {
    'persistenceState': persistenceState.stableId,
    'persistenceCode': persistenceCode.stableId,
    'stages': [
      for (final stage in MeetingIntelligenceStage.values)
        if (intelligence.outcomes[stage] case final outcome?)
          outcome.toDiagnosticMap(),
    ],
  };
}

class MeetingBackgroundJobHandle {
  const MeetingBackgroundJobHandle._({
    required this.completion,
    required this._cancellation,
  });

  final Future<MeetingBackgroundProcessingResult> completion;
  final MeetingIntelligenceCancellationToken _cancellation;

  void cancel() {
    _cancellation.cancel();
  }
}

class MeetingBackgroundProcessor {
  factory MeetingBackgroundProcessor({
    required MeetingRepository repository,
    required MeetingIntelligencePipeline pipeline,
    required MeetingIntelligenceCoordinator coordinator,
  }) {
    return MeetingBackgroundProcessor._(repository, pipeline, coordinator);
  }

  const MeetingBackgroundProcessor._(
    this._repository,
    this._pipeline,
    this._coordinator,
  );

  final MeetingRepository _repository;
  final MeetingIntelligencePipeline _pipeline;
  final MeetingIntelligenceCoordinator _coordinator;

  MeetingBackgroundJobHandle accept({
    required MeetingRecord record,
    required MeetingAudioMetadata audioMetadata,
    required List<TranscriptChunk> finalChunks,
    MeetingIntelligenceProgressCallback? onProgress,
  }) {
    if (audioMetadata.meetingId != record.id ||
        finalChunks.any((chunk) => chunk.meetingId != record.id)) {
      throw StateError('Meeting intelligence input IDs do not match.');
    }

    final redactedChunks = _pipeline.redactFinalChunks(finalChunks);
    final request = MeetingIntelligenceJobRequest(
      jobId: '${record.id}-intelligence',
      meetingId: record.id,
      stages: MeetingIntelligenceStage.values.toSet(),
      redactedTranscriptSegments: [
        for (final chunk in redactedChunks) chunk.text,
      ],
      localAudio: MeetingLocalAudioInput(
        localPath: audioMetadata.filePath,
        codec: audioMetadata.codec,
        sampleRateHz: audioMetadata.sampleRateHz,
        channelCount: audioMetadata.channelCount,
        sizeBytes: audioMetadata.sizeBytes,
        sha256: audioMetadata.sha256,
      ),
    );
    final cancellation = MeetingIntelligenceCancellationToken();
    final completion = Future<MeetingBackgroundProcessingResult>(() async {
      final intelligence = await _coordinator.run(
        request,
        cancellation: cancellation,
        onProgress: onProgress,
      );
      final summary = intelligence.summary;
      final searchIndex = intelligence.searchIndex;
      if (summary == null || searchIndex == null) {
        return MeetingBackgroundProcessingResult(
          intelligence: intelligence,
          persistenceState: MeetingBackgroundPersistenceState.skipped,
          persistenceCode: MeetingBackgroundPersistenceCode.stageIncomplete,
        );
      }

      final draft = _pipeline.draftFromProjections(
        record: record,
        audioMetadata: audioMetadata,
        redactedChunks: redactedChunks,
        summary: summary,
        searchIndex: searchIndex,
        embedding: intelligence.embedding,
      );
      try {
        await _repository.saveIntelligence(draft);
        return MeetingBackgroundProcessingResult(
          intelligence: intelligence,
          persistenceState: MeetingBackgroundPersistenceState.completed,
          persistenceCode: MeetingBackgroundPersistenceCode.completed,
        );
      } catch (_) {
        return MeetingBackgroundProcessingResult(
          intelligence: intelligence,
          persistenceState: MeetingBackgroundPersistenceState.failed,
          persistenceCode: MeetingBackgroundPersistenceCode.repositoryFailure,
        );
      }
    });

    return MeetingBackgroundJobHandle._(
      completion: completion,
      cancellation: cancellation,
    );
  }
}
