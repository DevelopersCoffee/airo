import 'package:airo_app/features/meeting/domain/entities/meeting_audio_metadata.dart';
import 'package:airo_app/features/meeting/domain/entities/meeting_intelligence.dart';
import 'package:airo_app/features/meeting/domain/entities/meeting_record.dart';
import 'package:airo_app/features/meeting/domain/entities/meeting_summary.dart';
import 'package:airo_app/features/meeting/domain/entities/transcript_chunk.dart';
import 'package:airo_app/features/meeting/infrastructure/storage/in_memory_meeting_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('InMemoryMeetingRepository.searchMeetings', () {
    test('matches project title and speaker labels', () async {
      final repository = InMemoryMeetingRepository();
      await repository.saveIntelligence(
        _draft(
          meetingId: 'meeting-1',
          title: 'Project Atlas kickoff',
          startedAt: DateTime.utc(2026, 6, 29, 9),
          searchableText: 'Action: finalize kickoff plan for Atlas.',
          chunks: const [
            TranscriptChunk.finalChunk(
              id: 'chunk-1',
              meetingId: 'meeting-1',
              text: 'Action: finalize kickoff plan for Atlas.',
              startMs: 0,
              endMs: 1000,
              speakerLabel: 'Priya',
            ),
          ],
        ),
      );

      final projectResults = await repository.searchMeetings('atlas');
      final speakerResults = await repository.searchMeetings('priya');

      expect(projectResults.map((result) => result.meetingId), ['meeting-1']);
      expect(speakerResults.map((result) => result.meetingId), ['meeting-1']);
    });

    test('handles simple misspellings and meeting-term synonyms', () async {
      final repository = InMemoryMeetingRepository();
      await repository.saveIntelligence(
        _draft(
          meetingId: 'meeting-2',
          title: 'Roadmap sync',
          startedAt: DateTime.utc(2026, 6, 29, 10),
          searchableText: 'Decision: launch plan stays local-first.',
          chunks: const [
            TranscriptChunk.finalChunk(
              id: 'chunk-2',
              meetingId: 'meeting-2',
              text: 'Decision: launch plan stays local-first.',
              startMs: 0,
              endMs: 1000,
            ),
          ],
        ),
      );

      final typoResults = await repository.searchMeetings('roadnmap');
      final synonymResults = await repository.searchMeetings('plan');

      expect(typoResults.map((result) => result.meetingId), ['meeting-2']);
      expect(synonymResults.map((result) => result.meetingId), ['meeting-2']);
    });

    test('normalizes mixed-language text with diacritics', () async {
      final repository = InMemoryMeetingRepository();
      await repository.saveIntelligence(
        _draft(
          meetingId: 'meeting-3',
          title: 'Diseño review',
          startedAt: DateTime.utc(2026, 6, 29, 11),
          searchableText: 'El diseño final queda aprobado para el proyecto.',
          languageCode: 'es',
          chunks: const [
            TranscriptChunk.finalChunk(
              id: 'chunk-3',
              meetingId: 'meeting-3',
              text: 'El diseño final queda aprobado para el proyecto.',
              startMs: 0,
              endMs: 1000,
            ),
          ],
        ),
      );

      final noAccentResults = await repository.searchMeetings('diseno');
      final projectResults = await repository.searchMeetings('proyecto');

      expect(noAccentResults.map((result) => result.meetingId), ['meeting-3']);
      expect(projectResults.map((result) => result.meetingId), ['meeting-3']);
    });

    test('keeps deterministic ordering for larger datasets', () async {
      final repository = InMemoryMeetingRepository();

      for (var i = 0; i < 60; i++) {
        await repository.saveIntelligence(
          _draft(
            meetingId: 'meeting-$i',
            title: 'Atlas search batch $i',
            startedAt: DateTime.utc(2026, 6, 1).add(Duration(minutes: i)),
            searchableText: 'Atlas rollout note $i',
            chunks: [
              TranscriptChunk.finalChunk(
                id: 'chunk-$i',
                meetingId: 'meeting-$i',
                text: 'Atlas rollout note $i',
                startMs: 0,
                endMs: 1000,
                speakerLabel: i.isEven ? 'Priya' : 'Amit',
              ),
            ],
          ),
        );
      }

      final results = await repository.searchMeetings('atlas');

      expect(results, hasLength(50));
      expect(results.first.meetingId, 'meeting-59');
      expect(results.last.meetingId, 'meeting-10');
    });
  });
}

MeetingIntelligenceDraft _draft({
  required String meetingId,
  required String title,
  required DateTime startedAt,
  required String searchableText,
  required List<TranscriptChunk> chunks,
  String? languageCode,
}) {
  final record = MeetingRecord.started(
    id: meetingId,
    title: title,
    startedAt: startedAt,
    languageCode: languageCode,
  ).complete(endedAt: startedAt.add(const Duration(minutes: 30)));

  return MeetingIntelligenceDraft(
    record: record,
    audioMetadata: MeetingAudioMetadata(
      meetingId: meetingId,
      filePath: '/tmp/$meetingId.m4a',
      codec: 'm4a',
      sampleRateHz: 16000,
      channelCount: 1,
      sizeBytes: 4096,
      sha256: 'sha-$meetingId',
    ),
    redactedChunks: chunks,
    summary: MeetingSummary(
      meetingId: meetingId,
      executiveSummary: 'summary',
      detailedSummary: 'detailed',
      actionItems: const [],
      keyDecisions: const [],
      risks: const [],
      nextSteps: const [],
      isCloudSyncEligible: false,
    ),
    searchableText: searchableText,
  );
}
