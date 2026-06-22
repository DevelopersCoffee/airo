import 'dart:async';

import 'package:airo_app/features/meeting/application/services/meeting_session_controller.dart';
import 'package:airo_app/features/meeting/domain/entities/meeting.dart';
import 'package:airo_app/features/meeting/domain/entities/transcript_chunk.dart';
import 'package:airo_app/features/meeting/domain/services/meeting_service_interfaces.dart';
import 'package:airo_app/features/meeting/infrastructure/storage/in_memory_meeting_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('MeetingSessionController', () {
    test(
      'starts, accepts partial/final transcript events, and finalizes intelligence',
      () async {
        final repository = InMemoryMeetingRepository();
        final controller = MeetingSessionController(repository: repository);

        final session = await controller.startMeeting(
          title: 'Product Planning',
        );
        controller.applyTranscriptEvent(
          const TranscriptChunk(
            id: 'partial_1',
            meetingId: 'ignored_until_controller_assigns',
            text: 'Decision: ship offline-first meeting search.',
            start: Duration.zero,
            end: Duration(seconds: 5),
            isFinal: false,
          ),
        );
        controller.applyTranscriptEvent(
          const TranscriptChunk(
            id: 'final_1',
            meetingId: 'ignored_until_controller_assigns',
            text: 'Decision: ship offline-first meeting search.',
            start: Duration.zero,
            end: Duration(seconds: 5),
            isFinal: true,
          ),
        );

        expect(controller.state.recordingState, RecordingState.recording);
        expect(controller.state.visibleTranscript, contains('offline-first'));

        final intelligence = await controller.stopMeeting();
        final chunks = await repository.getTranscriptChunks(session.id);

        expect(controller.state.recordingState, RecordingState.stopped);
        expect(chunks.single.isFinal, true);
        expect(
          intelligence.summary.keyDecisions.single,
          contains('offline-first meeting search'),
        );
      },
    );

    test(
      'subscribes to realtime transcript streams when a meeting starts',
      () async {
        final repository = InMemoryMeetingRepository();
        final transcription = _FakeMeetingTranscriptionService();
        final controller = MeetingSessionController(
          repository: repository,
          transcriptionService: transcription,
        );

        final session = await controller.startMeeting(title: 'Runtime Review');
        transcription.emitPartial(
          TranscriptChunk(
            id: 'partial_1',
            meetingId: session.id,
            text: 'Decision: wire realtime transcript streams',
            start: Duration.zero,
            end: const Duration(seconds: 3),
            isFinal: false,
          ),
        );
        await pumpEventQueue();

        expect(
          controller.state.visibleTranscript,
          contains('wire realtime transcript streams'),
        );

        transcription.emitFinal(
          TranscriptChunk(
            id: 'final_1',
            meetingId: session.id,
            text: 'Decision: wire realtime transcript streams.',
            start: Duration.zero,
            end: const Duration(seconds: 3),
            isFinal: true,
          ),
        );
        await pumpEventQueue();

        final intelligence = await controller.stopMeeting();
        final chunks = await repository.getTranscriptChunks(session.id);

        expect(transcription.started, true);
        expect(transcription.stopped, true);
        expect(chunks.single.text, contains('realtime transcript streams'));
        expect(
          intelligence.summary.keyDecisions.single,
          contains('wire realtime transcript streams'),
        );
        controller.dispose();
        transcription.dispose();
      },
    );

    test(
      'pauses, resumes, and promotes the last partial transcript on stop',
      () async {
        final repository = InMemoryMeetingRepository();
        final transcription = _FakeMeetingTranscriptionService();
        final controller = MeetingSessionController(
          repository: repository,
          transcriptionService: transcription,
        );

        final session = await controller.startMeeting(title: 'Quick Sync');
        transcription.emitPartial(
          TranscriptChunk(
            id: 'partial_only',
            meetingId: session.id,
            text: 'Action: Uday will verify the stop transcript flow.',
            start: Duration.zero,
            end: const Duration(seconds: 4),
            isFinal: false,
          ),
        );
        await pumpEventQueue();

        await controller.pauseMeeting();
        await controller.resumeMeeting();
        final intelligence = await controller.stopMeeting();
        final chunks = await repository.getTranscriptChunks(session.id);

        expect(transcription.paused, true);
        expect(transcription.resumed, true);
        expect(chunks.single.isFinal, true);
        expect(chunks.single.text, contains('stop transcript flow'));
        expect(intelligence.actionItems.single.owner, 'Uday');
        controller.dispose();
        transcription.dispose();
      },
    );
  });
}

class _FakeMeetingTranscriptionService implements MeetingTranscriptionService {
  final _partial = StreamController<TranscriptChunk>.broadcast();
  final _final = StreamController<TranscriptChunk>.broadcast();

  bool started = false;
  bool paused = false;
  bool resumed = false;
  bool stopped = false;

  @override
  Future<void> startRealtimeTranscription({required Meeting meeting}) async {
    started = true;
  }

  @override
  Future<void> pauseRealtimeTranscription() async {
    paused = true;
  }

  @override
  Future<void> resumeRealtimeTranscription() async {
    resumed = true;
  }

  @override
  Future<void> stopRealtimeTranscription() async {
    stopped = true;
  }

  @override
  Stream<TranscriptChunk> partialTranscript() => _partial.stream;

  @override
  Stream<TranscriptChunk> finalTranscript() => _final.stream;

  void emitPartial(TranscriptChunk chunk) => _partial.add(chunk);

  void emitFinal(TranscriptChunk chunk) => _final.add(chunk);

  void dispose() {
    _partial.close();
    _final.close();
  }
}
