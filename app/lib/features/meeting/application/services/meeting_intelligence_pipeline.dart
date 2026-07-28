import 'package:feature_meeting_intelligence/feature_meeting_intelligence.dart';

import '../../domain/entities/meeting_audio_metadata.dart';
import '../../domain/entities/meeting_intelligence.dart';
import '../../domain/entities/meeting_record.dart';
import '../../domain/entities/meeting_summary.dart';
import '../../domain/entities/transcript_chunk.dart';
import '../../domain/services/meeting_redaction_service.dart';

class MeetingIntelligencePipeline {
  MeetingIntelligencePipeline({MeetingRedactionService? redactionService})
    : _redactionService = redactionService ?? MeetingRedactionService();

  final MeetingRedactionService _redactionService;

  MeetingIntelligenceDraft process({
    required MeetingRecord record,
    required MeetingAudioMetadata audioMetadata,
    required List<TranscriptChunk> finalChunks,
  }) {
    final redactedChunks = redactFinalChunks(finalChunks);
    final request = MeetingIntelligenceJobRequest(
      jobId: '${record.id}-synchronous',
      meetingId: record.id,
      stages: const {
        MeetingIntelligenceStage.summary,
        MeetingIntelligenceStage.searchIndexing,
      },
      redactedTranscriptSegments: [
        for (final chunk in redactedChunks) chunk.text,
      ],
    );
    final summary = const DeterministicMeetingSummaryProvider().process(
      request,
    );
    final searchIndex = const DeterministicMeetingSearchIndexProvider().process(
      request,
    );
    return draftFromProjections(
      record: record,
      audioMetadata: audioMetadata,
      redactedChunks: redactedChunks,
      summary: summary,
      searchIndex: searchIndex,
    );
  }

  List<TranscriptChunk> redactFinalChunks(List<TranscriptChunk> finalChunks) {
    return finalChunks
        .where((chunk) => chunk.isFinal)
        .map(
          (chunk) => chunk.copyWith(
            text: _redactionService.redact(chunk.text),
            redactionStatus: TranscriptRedactionStatus.redacted,
          ),
        )
        .toList(growable: false);
  }

  MeetingIntelligenceDraft draftFromProjections({
    required MeetingRecord record,
    required MeetingAudioMetadata audioMetadata,
    required List<TranscriptChunk> redactedChunks,
    required MeetingSummaryProjection summary,
    required MeetingSearchIndexProjection searchIndex,
  }) {
    return MeetingIntelligenceDraft(
      record: record,
      audioMetadata: audioMetadata,
      redactedChunks: redactedChunks,
      summary: MeetingSummary(
        meetingId: record.id,
        executiveSummary: summary.executiveSummary,
        detailedSummary: summary.detailedSummary,
        actionItems: [
          for (var index = 0; index < summary.actionItems.length; index += 1)
            MeetingActionItem(
              id: '${record.id}-action-${index + 1}',
              meetingId: record.id,
              description: summary.actionItems[index],
            ),
        ],
        keyDecisions: summary.keyDecisions,
        risks: summary.risks,
        openQuestions: summary.openQuestions,
        followUps: summary.followUps,
        blockers: summary.blockers,
        dependencies: summary.dependencies,
        nextSteps: summary.nextSteps,
        isCloudSyncEligible: false,
      ),
      searchableText: searchIndex.searchableText,
    );
  }
}
