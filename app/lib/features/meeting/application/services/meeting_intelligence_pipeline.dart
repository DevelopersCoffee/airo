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
    final redactedChunks = finalChunks
        .where((chunk) => chunk.isFinal)
        .map(
          (chunk) => chunk.copyWith(
            text: _redactionService.redact(chunk.text),
            redactionStatus: TranscriptRedactionStatus.redacted,
          ),
        )
        .toList(growable: false);
    final searchableText = redactedChunks.map((chunk) => chunk.text).join('\n');

    return MeetingIntelligenceDraft(
      record: record,
      audioMetadata: audioMetadata,
      redactedChunks: redactedChunks,
      summary: MeetingSummary(
        meetingId: record.id,
        executiveSummary: _buildExecutiveSummary(searchableText),
        detailedSummary: searchableText,
        actionItems: _extractActionItems(record.id, searchableText),
        keyDecisions: _extractPrefixedLines(searchableText, 'decision:'),
        risks: _extractRiskLines(searchableText),
        openQuestions: _extractAnyPrefixedLines(searchableText, const [
          'open question:',
          'question:',
        ]),
        followUps: _extractAnyPrefixedLines(searchableText, const [
          'follow-up:',
          'followup:',
        ]),
        blockers: _extractAnyPrefixedLines(searchableText, const [
          'blocker:',
          'blocked by:',
        ]),
        dependencies: _extractAnyPrefixedLines(searchableText, const [
          'dependency:',
          'depends on:',
        ]),
        nextSteps: _extractPrefixedLines(searchableText, 'next:'),
        isCloudSyncEligible: false,
      ),
      searchableText: searchableText,
    );
  }

  String _buildExecutiveSummary(String searchableText) {
    final normalized = searchableText.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (normalized.isEmpty) {
      return 'No final transcript was captured.';
    }
    return normalized.length <= 240
        ? normalized
        : '${normalized.substring(0, 237)}...';
  }

  List<MeetingActionItem> _extractActionItems(String meetingId, String text) {
    final actionLines = _extractPrefixedLines(text, 'action:');
    return [
      for (var index = 0; index < actionLines.length; index += 1)
        MeetingActionItem(
          id: '$meetingId-action-${index + 1}',
          meetingId: meetingId,
          description: actionLines[index],
        ),
    ];
  }

  List<String> _extractRiskLines(String text) {
    return text
        .split(RegExp(r'[\n.]'))
        .map((line) => line.trim())
        .where((line) => line.toLowerCase().contains('risk'))
        .toList(growable: false);
  }

  List<String> _extractPrefixedLines(String text, String prefix) {
    return _extractAnyPrefixedLines(text, [prefix]);
  }

  List<String> _extractAnyPrefixedLines(String text, List<String> prefixes) {
    return text
        .split(RegExp(r'[\n.]'))
        .map((line) => line.trim())
        .map((line) {
          final normalized = line.toLowerCase();
          for (final prefix in prefixes) {
            if (normalized.startsWith(prefix)) {
              return line.substring(prefix.length).trim();
            }
          }
          return null;
        })
        .whereType<String>()
        .where((line) => line.isNotEmpty)
        .toList(growable: false);
  }
}
