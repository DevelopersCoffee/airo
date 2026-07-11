import 'package:airo_app/core/database/app_database.dart' show AppDatabase;
import 'package:airo_app/features/meeting/application/services/meeting_intelligence_pipeline.dart';
import 'package:airo_app/features/meeting/domain/entities/meeting_audio_metadata.dart';
import 'package:airo_app/features/meeting/domain/entities/meeting_intelligence.dart';
import 'package:airo_app/features/meeting/domain/entities/meeting_record.dart';
import 'package:airo_app/features/meeting/domain/entities/meeting_summary.dart';
import 'package:airo_app/features/meeting/domain/entities/transcript_chunk.dart';
import 'package:airo_app/features/meeting/infrastructure/storage/drift_meeting_repository.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late DriftMeetingRepository repository;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repository = DriftMeetingRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  group('DriftMeetingRepository', () {
    test(
      'saves and retrieves a completed meeting intelligence draft',
      () async {
        final draft = MeetingIntelligencePipeline().process(
          record: MeetingRecord.started(
            id: 'meeting-complete',
            title: 'Launch review',
            startedAt: DateTime.utc(2026, 6, 22, 10),
            languageCode: 'en-IN',
          ).complete(endedAt: DateTime.utc(2026, 6, 22, 10, 30)),
          audioMetadata: const MeetingAudioMetadata(
            meetingId: 'meeting-complete',
            filePath: '/private/local/meeting-complete.m4a',
            codec: 'm4a',
            sampleRateHz: 16000,
            channelCount: 1,
            sizeBytes: 4096,
            sha256: 'sha-complete',
          ),
          finalChunks: const [
            TranscriptChunk.finalChunk(
              id: 'chunk-1',
              meetingId: 'meeting-complete',
              text: 'Action: Priya to publish local-only notes.',
              startMs: 0,
              endMs: 2000,
              speakerLabel: 'Priya',
              confidence: 0.93,
            ),
            TranscriptChunk.finalChunk(
              id: 'chunk-2',
              meetingId: 'meeting-complete',
              text: 'Decision: Keep raw audio on device.',
              startMs: 2000,
              endMs: 4000,
              speakerLabel: 'Arjun',
              confidence: 0.91,
            ),
          ],
        );

        await repository.saveIntelligence(draft);

        final savedRecord = await repository.meetingById('meeting-complete');
        expect(savedRecord, isNotNull);
        expect(savedRecord!.title, 'Launch review');
        expect(savedRecord.startedAt, DateTime.utc(2026, 6, 22, 10));
        expect(savedRecord.endedAt, DateTime.utc(2026, 6, 22, 10, 30));
        expect(savedRecord.state, MeetingState.completed);
        expect(savedRecord.languageCode, 'en-IN');

        final savedChunks = await repository.transcriptChunksForMeeting(
          'meeting-complete',
        );
        expect(savedChunks, hasLength(2));
        expect(savedChunks.first.id, 'chunk-1');
        expect(savedChunks.first.speakerLabel, 'Priya');
        expect(savedChunks.first.confidence, 0.93);
        expect(savedChunks.every((chunk) => chunk.isFinal), isTrue);
        expect(
          savedChunks.every(
            (chunk) =>
                chunk.redactionStatus == TranscriptRedactionStatus.redacted,
          ),
          isTrue,
        );

        final savedSummary = await repository.summaryForMeeting(
          'meeting-complete',
        );
        expect(savedSummary, isNotNull);
        expect(savedSummary!.actionItems.single.description, contains('Priya'));
        expect(savedSummary.keyDecisions, ['Keep raw audio on device']);
        expect(savedSummary.isCloudSyncEligible, isFalse);

        final savedAudio = await repository.audioMetadataForMeeting(
          'meeting-complete',
        );
        expect(savedAudio, isNotNull);
        expect(savedAudio!.filePath, '/private/local/meeting-complete.m4a');
        expect(savedAudio.sha256, 'sha-complete');

        final searchResults = await repository.searchMeetings('local-only');
        expect(searchResults.map((result) => result.meetingId), [
          'meeting-complete',
        ]);
      },
    );

    test('returns null and empty lists for a missing meeting', () async {
      expect(await repository.meetingById('missing'), isNull);
      expect(await repository.summaryForMeeting('missing'), isNull);
      expect(await repository.audioMetadataForMeeting('missing'), isNull);
      expect(await repository.transcriptChunksForMeeting('missing'), isEmpty);
      expect(await repository.searchMeetings('missing'), isEmpty);
    });

    test('preserves empty strings and edge timestamps', () async {
      final earliest = DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
      const meetingId = 'meeting-edge';
      await repository.saveIntelligence(
        MeetingIntelligenceDraft(
          record: MeetingRecord(
            id: meetingId,
            title: '',
            startedAt: earliest,
            endedAt: earliest,
            state: MeetingState.completed,
            languageCode: '',
          ),
          audioMetadata: const MeetingAudioMetadata(
            meetingId: meetingId,
            filePath: '',
            codec: '',
            sampleRateHz: 0,
            channelCount: 0,
            sizeBytes: 0,
            sha256: '',
          ),
          redactedChunks: const [
            TranscriptChunk(
              id: 'chunk-edge',
              meetingId: meetingId,
              text: '',
              startMs: 0,
              endMs: 0,
              isFinal: true,
              confidence: 0,
              redactionStatus: TranscriptRedactionStatus.redacted,
            ),
          ],
          summary: const MeetingSummary(
            meetingId: meetingId,
            executiveSummary: '',
            detailedSummary: '',
            actionItems: [],
            keyDecisions: [],
            risks: [],
            openQuestions: [],
            followUps: [],
            blockers: [],
            dependencies: [],
            nextSteps: [],
            isCloudSyncEligible: false,
          ),
          searchableText: '',
        ),
      );

      final savedRecord = await repository.meetingById(meetingId);
      expect(savedRecord, isNotNull);
      expect(savedRecord!.title, '');
      expect(savedRecord.startedAt, earliest);
      expect(savedRecord.endedAt, earliest);
      expect(savedRecord.languageCode, '');

      final chunks = await repository.transcriptChunksForMeeting(meetingId);
      expect(chunks.single.text, '');
      expect(chunks.single.confidence, 0);

      final audio = await repository.audioMetadataForMeeting(meetingId);
      expect(audio!.filePath, '');
      expect(audio.sha256, '');
    });

    test(
      'redacts sensitive values defensively before durable storage',
      () async {
        await repository.saveIntelligence(
          MeetingIntelligenceDraft(
            record: MeetingRecord(
              id: 'meeting-sensitive',
              title: 'Sensitive sync',
              startedAt: DateTime.utc(2026, 6, 22),
              state: MeetingState.completed,
              languageCode: 'en',
            ),
            audioMetadata: MeetingAudioMetadata(
              meetingId: 'meeting-sensitive',
              filePath: '/private/local/sensitive.m4a',
              codec: 'm4a',
              sampleRateHz: 16000,
              channelCount: 1,
              sizeBytes: 128,
              sha256: 'sensitive',
            ),
            redactedChunks: [
              TranscriptChunk.finalChunk(
                id: 'chunk-sensitive',
                meetingId: 'meeting-sensitive',
                text: 'Call +91 98765 43210 and card 4242 4242 4242 4242.',
                startMs: 0,
                endMs: 1000,
              ),
            ],
            summary: MeetingSummary(
              meetingId: 'meeting-sensitive',
              executiveSummary: 'Call +91 98765 43210',
              detailedSummary: 'Card 4242 4242 4242 4242',
              actionItems: [
                MeetingActionItem(
                  id: 'action-sensitive',
                  meetingId: 'meeting-sensitive',
                  description: 'Call +91 98765 43210',
                ),
              ],
              keyDecisions: ['Use card 4242 4242 4242 4242'],
              risks: [],
              openQuestions: [],
              followUps: [],
              blockers: [],
              dependencies: [],
              nextSteps: ['Call +91 98765 43210'],
              isCloudSyncEligible: true,
            ),
            searchableText: 'card 4242 4242 4242 4242 phone +91 98765 43210',
          ),
        );

        final chunks = await repository.transcriptChunksForMeeting(
          'meeting-sensitive',
        );
        expect(chunks.single.text, contains('[REDACTED_PHONE]'));
        expect(chunks.single.text, contains('[REDACTED_CARD]'));
        expect(chunks.single.text, isNot(contains('98765')));
        expect(chunks.single.text, isNot(contains('4242')));

        final summary = await repository.summaryForMeeting('meeting-sensitive');
        expect(summary!.executiveSummary, contains('[REDACTED_PHONE]'));
        expect(summary.detailedSummary, contains('[REDACTED_CARD]'));
        expect(
          summary.actionItems.single.description,
          contains('[REDACTED_PHONE]'),
        );
        expect(summary.keyDecisions.single, contains('[REDACTED_CARD]'));
        expect(summary.nextSteps.single, contains('[REDACTED_PHONE]'));
        expect(summary.isCloudSyncEligible, isFalse);

        expect(await repository.searchMeetings('4242'), isEmpty);
        expect(await repository.searchMeetings('98765'), isEmpty);
      },
    );
  });
}
