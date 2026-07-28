import 'package:feature_meeting_intelligence/feature_meeting_intelligence.dart';

import '../../domain/entities/meeting_audio_metadata.dart';
import '../../domain/entities/meeting_record.dart';
import '../../domain/entities/transcript_chunk.dart';
import '../../domain/repositories/meeting_repository.dart';
import 'meeting_background_processor.dart';
import 'meeting_intelligence_pipeline.dart';

class MeetingSessionController {
  MeetingSessionController({
    required MeetingRepository repository,
    MeetingIntelligencePipeline? pipeline,
    MeetingBackgroundProcessor? backgroundProcessor,
    MeetingEmbeddingStageProvider? embeddingProvider,
    DateTime Function()? now,
  }) : _backgroundProcessor =
           backgroundProcessor ??
           MeetingBackgroundProcessor(
             repository: repository,
             pipeline: pipeline ?? MeetingIntelligencePipeline(),
             coordinator: MeetingIntelligenceCoordinator.deterministic(
               embeddingProvider: embeddingProvider,
             ),
           ),
       _now = now ?? DateTime.now;

  final MeetingBackgroundProcessor _backgroundProcessor;
  final DateTime Function() _now;
  final List<TranscriptChunk> _partialChunks = [];
  final List<TranscriptChunk> _finalChunks = [];
  MeetingRecord? _activeRecord;
  MeetingBackgroundJobHandle? _lastBackgroundJob;

  MeetingBackgroundJobHandle? get lastBackgroundJob => _lastBackgroundJob;

  String get partialTranscriptText {
    return _partialChunks.map((chunk) => chunk.text).join('\n');
  }

  Future<MeetingRecord> startMeeting({
    required String id,
    required String title,
    String? languageCode,
  }) async {
    _partialChunks.clear();
    _finalChunks.clear();
    final record = MeetingRecord.started(
      id: id,
      title: title,
      startedAt: _now(),
      languageCode: languageCode,
    );
    _activeRecord = record;
    return record;
  }

  void receiveTranscriptChunk(TranscriptChunk chunk) {
    final activeRecord = _activeRecord;
    if (activeRecord == null || chunk.meetingId != activeRecord.id) {
      throw StateError(
        'Transcript chunk does not belong to the active meeting.',
      );
    }

    if (chunk.isFinal) {
      _finalChunks.add(chunk);
      return;
    }

    _partialChunks.add(chunk);
  }

  Future<MeetingRecord> completeMeeting({
    required MeetingAudioMetadata audioMetadata,
  }) async {
    final activeRecord = _activeRecord;
    if (activeRecord == null) {
      throw StateError('No active meeting to complete.');
    }
    if (audioMetadata.meetingId != activeRecord.id) {
      throw StateError('Audio metadata does not belong to the active meeting.');
    }

    final completedRecord = activeRecord.complete(endedAt: _now());
    _lastBackgroundJob = _backgroundProcessor.accept(
      record: completedRecord,
      audioMetadata: audioMetadata,
      finalChunks: List.unmodifiable(_finalChunks),
    );
    _partialChunks.clear();
    _finalChunks.clear();
    _activeRecord = null;
    return completedRecord;
  }
}
