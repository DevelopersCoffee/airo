import 'package:airo_app/features/meeting/domain/entities/meeting.dart';
import 'package:airo_app/features/meeting/domain/entities/transcript_chunk.dart';
import 'package:airo_app/features/meeting/infrastructure/storage/in_memory_meeting_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('InMemoryMeetingRepository', () {
    test(
      'persists meeting, transcript chunks, and semantic search metadata locally',
      () async {
        final repository = InMemoryMeetingRepository();
        final meeting = Meeting(
          id: 'meeting_1',
          title: 'Onboarding Architecture',
          startedAt: DateTime(2026, 6, 22, 9),
          endedAt: DateTime(2026, 6, 22, 9, 45),
          state: MeetingState.completed,
        );

        await repository.saveMeeting(meeting);
        await repository.saveTranscriptChunk(
          const TranscriptChunk(
            id: 'chunk_1',
            meetingId: 'meeting_1',
            text:
                'We decided authentication remains local-first with optional sync.',
            start: Duration.zero,
            end: Duration(seconds: 15),
            isFinal: true,
          ),
        );
        await repository.saveEmbedding(
          meetingId: 'meeting_1',
          chunkId: 'chunk_1',
          vector: List<double>.filled(32, 0.25),
          searchableText: 'authentication local-first optional sync',
        );

        final saved = await repository.getMeeting('meeting_1');
        final chunks = await repository.getTranscriptChunks('meeting_1');
        final results = await repository.search(
          'What did we decide about authentication?',
          limit: 5,
        );

        expect(saved?.title, 'Onboarding Architecture');
        expect(chunks.single.text, contains('authentication'));
        expect(results.single.meetingId, 'meeting_1');
        expect(results.single.matchedText, contains('authentication'));
        expect(results.single.score, greaterThan(0));
      },
    );
  });
}
