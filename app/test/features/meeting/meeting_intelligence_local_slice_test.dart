import 'package:airo_app/features/meeting/application/services/meeting_intelligence_pipeline.dart';
import 'package:airo_app/features/meeting/application/services/meeting_session_controller.dart';
import 'package:airo_app/features/meeting/domain/entities/meeting_audio_metadata.dart';
import 'package:airo_app/features/meeting/domain/entities/meeting_record.dart';
import 'package:airo_app/features/meeting/domain/entities/transcript_chunk.dart';
import 'package:airo_app/features/meeting/infrastructure/storage/in_memory_meeting_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Meeting Intelligence local-first slice', () {
    test(
      'redacts sensitive values before saving summaries and transcript search',
      () async {
        final repository = InMemoryMeetingRepository();
        final pipeline = MeetingIntelligencePipeline();
        final record = MeetingRecord.started(
          id: 'meeting-1',
          title: 'Roadmap sync',
          startedAt: DateTime.utc(2026, 6, 22, 10),
        );
        const audio = MeetingAudioMetadata(
          meetingId: 'meeting-1',
          filePath: '/private/var/mobile/Containers/Data/meeting-1.m4a',
          codec: 'm4a',
          sampleRateHz: 16000,
          channelCount: 1,
          sizeBytes: 4096,
          sha256: 'abc123',
        );

        final draft = pipeline.process(
          record: record.complete(endedAt: DateTime.utc(2026, 6, 22, 10, 30)),
          audioMetadata: audio,
          finalChunks: const [
            TranscriptChunk.finalChunk(
              id: 'chunk-1',
              meetingId: 'meeting-1',
              text:
                  'Call me at +91 98765 43210 about card 4242 4242 4242 4242 and budget risk.',
              startMs: 0,
              endMs: 5000,
            ),
            TranscriptChunk.finalChunk(
              id: 'chunk-2',
              meetingId: 'meeting-1',
              text: 'Action: Priya to share offline launch notes by Friday.',
              startMs: 5000,
              endMs: 9000,
            ),
          ],
        );

        await repository.saveIntelligence(draft);

        final chunks = await repository.transcriptChunksForMeeting('meeting-1');
        expect(
          chunks.map((chunk) => chunk.text).join(' '),
          isNot(contains('98765')),
        );
        expect(
          chunks.map((chunk) => chunk.text).join(' '),
          isNot(contains('4242')),
        );
        expect(chunks.first.text, contains('[REDACTED_PHONE]'));
        expect(chunks.first.text, contains('[REDACTED_CARD]'));

        final summary = await repository.summaryForMeeting('meeting-1');
        expect(summary, isNotNull);
        expect(summary!.executiveSummary, isNot(contains('98765')));
        expect(summary.executiveSummary, contains('[REDACTED_PHONE]'));
        expect(
          summary.actionItems.single.description,
          contains('Priya to share offline launch notes'),
        );
        expect(summary.isCloudSyncEligible, isFalse);

        final budgetResults = await repository.searchMeetings('budget risk');
        expect(
          budgetResults.map((result) => result.meetingId),
          contains('meeting-1'),
        );

        final sensitiveResults = await repository.searchMeetings('4242');
        expect(sensitiveResults, isEmpty);
      },
    );

    test(
      'keeps partial transcript updates volatile and persists only final chunks locally',
      () async {
        final repository = InMemoryMeetingRepository();
        final controller = MeetingSessionController(
          repository: repository,
          pipeline: MeetingIntelligencePipeline(),
          now: () => DateTime.utc(2026, 6, 22, 11),
        );

        await controller.startMeeting(id: 'meeting-2', title: 'Design review');
        controller.receiveTranscriptChunk(
          const TranscriptChunk.partial(
            id: 'partial-1',
            meetingId: 'meeting-2',
            text: 'temporary partial with +91 99999 88888',
            startMs: 0,
            endMs: 1000,
          ),
        );
        controller.receiveTranscriptChunk(
          const TranscriptChunk.finalChunk(
            id: 'final-1',
            meetingId: 'meeting-2',
            text: 'Final note: confirm local-only transcription path.',
            startMs: 1000,
            endMs: 2500,
          ),
        );

        expect(controller.partialTranscriptText, contains('temporary partial'));
        expect(
          await repository.transcriptChunksForMeeting('meeting-2'),
          isEmpty,
        );

        await controller.completeMeeting(
          audioMetadata: const MeetingAudioMetadata(
            meetingId: 'meeting-2',
            filePath: '/private/local/meeting-2.wav',
            codec: 'wav',
            sampleRateHz: 16000,
            channelCount: 1,
            sizeBytes: 2048,
            sha256: 'def456',
          ),
        );

        expect(controller.partialTranscriptText, isEmpty);
        final persisted = await repository.transcriptChunksForMeeting(
          'meeting-2',
        );
        expect(persisted, hasLength(1));
        expect(persisted.single.id, 'final-1');
        expect(
          persisted.single.text,
          contains('local-only transcription path'),
        );
        expect(persisted.single.text, isNot(contains('99999')));

        final savedRecord = await repository.meetingById('meeting-2');
        expect(savedRecord, isNotNull);
        expect(savedRecord!.state, MeetingState.completed);
      },
    );

    test(
      'finds misspelled, speaker, title, synonym, and mixed-language queries',
      () async {
        final repository = InMemoryMeetingRepository();
        final pipeline = MeetingIntelligencePipeline();

        await repository.saveIntelligence(
          pipeline.process(
            record: MeetingRecord.started(
              id: 'meeting-roadmap',
              title: 'Apollo roadmap review',
              startedAt: DateTime.utc(2026, 6, 22, 9),
              languageCode: 'en',
            ).complete(endedAt: DateTime.utc(2026, 6, 22, 9, 45)),
            audioMetadata: const MeetingAudioMetadata(
              meetingId: 'meeting-roadmap',
              filePath: '/private/local/roadmap.m4a',
              codec: 'm4a',
              sampleRateHz: 16000,
              channelCount: 1,
              sizeBytes: 4096,
              sha256: 'roadmap',
            ),
            finalChunks: const [
              TranscriptChunk.finalChunk(
                id: 'chunk-roadmap-1',
                meetingId: 'meeting-roadmap',
                text: 'Budget risk remains high for the Apollo launch project.',
                startMs: 0,
                endMs: 2000,
                speakerLabel: 'Priya',
              ),
              TranscriptChunk.finalChunk(
                id: 'chunk-roadmap-2',
                meetingId: 'meeting-roadmap',
                text: 'Decision: Ship the offline beta next Friday.',
                startMs: 2000,
                endMs: 3500,
                speakerLabel: 'Arjun',
              ),
            ],
          ),
        );

        await repository.saveIntelligence(
          pipeline.process(
            record: MeetingRecord.started(
              id: 'meeting-hindi',
              title: 'हिंदी लॉन्च समन्वय',
              startedAt: DateTime.utc(2026, 6, 21, 9),
              languageCode: 'hi',
            ).complete(endedAt: DateTime.utc(2026, 6, 21, 9, 30)),
            audioMetadata: const MeetingAudioMetadata(
              meetingId: 'meeting-hindi',
              filePath: '/private/local/hindi.m4a',
              codec: 'm4a',
              sampleRateHz: 16000,
              channelCount: 1,
              sizeBytes: 2048,
              sha256: 'hindi',
            ),
            finalChunks: const [
              TranscriptChunk.finalChunk(
                id: 'chunk-hindi-1',
                meetingId: 'meeting-hindi',
                text: 'परियोजना लॉन्च अगले सप्ताह है और टीम तैयार है।',
                startMs: 0,
                endMs: 1800,
                speakerLabel: 'नेहा',
              ),
            ],
          ),
        );

        final typoResults = await repository.searchMeetings('budjet');
        expect(typoResults.map((result) => result.meetingId), [
          'meeting-roadmap',
        ]);

        final speakerResults = await repository.searchMeetings('priya');
        expect(
          speakerResults.map((result) => result.meetingId),
          contains('meeting-roadmap'),
        );

        final titleResults = await repository.searchMeetings('apollo');
        expect(titleResults.single.meetingId, 'meeting-roadmap');
        expect(titleResults.single.title, contains('Apollo roadmap'));

        final synonymResults = await repository.searchMeetings('finance');
        expect(synonymResults.single.meetingId, 'meeting-roadmap');

        final mixedLanguageResults = await repository.searchMeetings(
          'परियोजना',
        );
        expect(mixedLanguageResults.single.meetingId, 'meeting-hindi');
      },
    );

    test('keeps deterministic ordering for larger repositories', () async {
      final repository = InMemoryMeetingRepository();
      final pipeline = MeetingIntelligencePipeline();

      for (var index = 0; index < 60; index += 1) {
        final meetingId = 'meeting-$index';
        final title = index.isEven
            ? 'Phoenix project sync $index'
            : 'General sync $index';
        final text = index.isEven
            ? 'Project Phoenix budget issue discussed by speaker Maya.'
            : 'Unrelated retrospective notes.';

        await repository.saveIntelligence(
          pipeline.process(
            record:
                MeetingRecord.started(
                  id: meetingId,
                  title: title,
                  startedAt: DateTime.utc(
                    2026,
                    6,
                    1,
                  ).add(Duration(days: index)),
                  languageCode: 'en',
                ).complete(
                  endedAt: DateTime.utc(
                    2026,
                    6,
                    1,
                  ).add(Duration(days: index, minutes: 30)),
                ),
            audioMetadata: MeetingAudioMetadata(
              meetingId: meetingId,
              filePath: '/private/local/$meetingId.m4a',
              codec: 'm4a',
              sampleRateHz: 16000,
              channelCount: 1,
              sizeBytes: 1000 + index,
              sha256: 'sha-$index',
            ),
            finalChunks: [
              TranscriptChunk.finalChunk(
                id: 'chunk-$index',
                meetingId: meetingId,
                text: text,
                startMs: 0,
                endMs: 1000,
                speakerLabel: index.isEven ? 'Maya' : 'Alex',
              ),
            ],
          ),
        );
      }

      final firstRun = await repository.searchMeetings('project maya');
      final secondRun = await repository.searchMeetings('project maya');

      expect(firstRun, isNotEmpty);
      expect(
        firstRun.map((result) => result.meetingId).toList(),
        secondRun.map((result) => result.meetingId).toList(),
      );
      expect(firstRun.first.meetingId, 'meeting-58');
      expect(
        firstRun.take(5).every((result) => result.title.contains('Phoenix')),
        isTrue,
      );
    });
  });
}
