import '../entities/meeting.dart';
import '../entities/transcript_chunk.dart';

abstract class MeetingRecorderService {
  Future<Meeting> startMeeting({required String title});
  Future<void> pauseMeeting();
  Future<void> resumeMeeting();
  Future<Meeting> stopMeeting();
  Future<void> cancelMeeting();
  Duration recordingDuration();
  Stream<RecordingState> recordingState();
  Stream<double> audioLevel();
}

abstract class MeetingTranscriptionService {
  Future<void> startRealtimeTranscription({required Meeting meeting});
  Future<void> pauseRealtimeTranscription();
  Future<void> resumeRealtimeTranscription();
  Future<void> stopRealtimeTranscription();
  Stream<TranscriptChunk> partialTranscript();
  Stream<TranscriptChunk> finalTranscript();
}
