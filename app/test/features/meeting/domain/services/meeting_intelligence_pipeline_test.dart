import 'package:airo_app/features/meeting/domain/entities/meeting.dart';
import 'package:airo_app/features/meeting/domain/entities/transcript_chunk.dart';
import 'package:airo_app/features/meeting/domain/services/meeting_intelligence_pipeline.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('MeetingIntelligencePipeline', () {
    test(
      'generates structured meeting intelligence from transcript chunks',
      () async {
        final pipeline = MeetingIntelligencePipeline();
        final meeting = Meeting(
          id: 'meeting_1',
          title: 'Flutter Architecture Review',
          startedAt: DateTime(2026, 6, 22, 10),
          endedAt: DateTime(2026, 6, 22, 10, 30),
          state: MeetingState.completed,
        );

        final output = await pipeline.process(
          meeting: meeting,
          chunks: const [
            TranscriptChunk(
              id: 'chunk_1',
              meetingId: 'meeting_1',
              text: 'Decision: use clean architecture for the Flutter module.',
              start: Duration.zero,
              end: Duration(seconds: 12),
              isFinal: true,
            ),
            TranscriptChunk(
              id: 'chunk_2',
              meetingId: 'meeting_1',
              text:
                  'Action: Uday will validate whisper.cpp battery usage by Friday.',
              start: Duration(seconds: 12),
              end: Duration(seconds: 28),
              isFinal: true,
            ),
            TranscriptChunk(
              id: 'chunk_3',
              meetingId: 'meeting_1',
              text:
                  'Risk: on-device models may be too large for low storage phones.',
              start: Duration(seconds: 28),
              end: Duration(seconds: 42),
              isFinal: true,
            ),
          ],
        );

        expect(
          output.summary.executiveSummary,
          contains('Flutter Architecture Review'),
        );
        expect(
          output.summary.keyDecisions,
          contains('use clean architecture for the Flutter module.'),
        );
        expect(
          output.summary.risks,
          contains('on-device models may be too large for low storage phones.'),
        );
        expect(output.actionItems.single.owner, 'Uday');
        expect(
          output.actionItems.single.description,
          contains('validate whisper.cpp battery usage'),
        );
        expect(output.topics, contains('flutter architecture'));
        expect(output.embedding.vector.length, 32);
      },
    );

    test(
      'redacts likely sensitive data before summary and embedding storage',
      () async {
        final pipeline = MeetingIntelligencePipeline();

        final output = await pipeline.process(
          meeting: Meeting(
            id: 'meeting_2',
            title: 'Vendor Call',
            startedAt: DateTime(2026, 6, 22, 11),
            endedAt: DateTime(2026, 6, 22, 11, 20),
            state: MeetingState.completed,
          ),
          chunks: const [
            TranscriptChunk(
              id: 'chunk_1',
              meetingId: 'meeting_2',
              text:
                  'My phone is +91 98765 43210 and card is 4111 1111 1111 1111.',
              start: Duration.zero,
              end: Duration(seconds: 8),
              isFinal: true,
            ),
          ],
        );

        expect(output.cleanedTranscript, isNot(contains('98765')));
        expect(output.cleanedTranscript, isNot(contains('4111')));
        expect(output.cleanedTranscript, contains('[phone]'));
        expect(output.cleanedTranscript, contains('[card]'));
        expect(output.privacy.isOfflineOnly, true);
      },
    );
  });
}
