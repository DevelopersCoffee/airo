import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../../domain/entities/meeting.dart';
import '../../domain/entities/meeting_intelligence.dart';
import '../../domain/entities/transcript_chunk.dart';
import '../../domain/repositories/meeting_repository.dart';
import '../../domain/services/meeting_intelligence_pipeline.dart';
import '../../domain/services/meeting_service_interfaces.dart';

class MeetingSessionState {
  const MeetingSessionState({
    required this.recordingState,
    this.meeting,
    this.finalTranscript = '',
    this.partialTranscript = '',
    this.audioLevel = 0,
    this.errorMessage,
  });

  final RecordingState recordingState;
  final Meeting? meeting;
  final String finalTranscript;
  final String partialTranscript;
  final double audioLevel;
  final String? errorMessage;

  String get visibleTranscript {
    return [
      finalTranscript.trim(),
      partialTranscript.trim(),
    ].where((part) => part.isNotEmpty).join('\n');
  }

  MeetingSessionState copyWith({
    RecordingState? recordingState,
    Meeting? meeting,
    String? finalTranscript,
    String? partialTranscript,
    double? audioLevel,
    String? errorMessage,
  }) {
    return MeetingSessionState(
      recordingState: recordingState ?? this.recordingState,
      meeting: meeting ?? this.meeting,
      finalTranscript: finalTranscript ?? this.finalTranscript,
      partialTranscript: partialTranscript ?? this.partialTranscript,
      audioLevel: audioLevel ?? this.audioLevel,
      errorMessage: errorMessage,
    );
  }
}

class MeetingSessionController extends ChangeNotifier {
  MeetingSessionController({
    required MeetingRepository repository,
    MeetingIntelligencePipeline pipeline = const MeetingIntelligencePipeline(),
    MeetingTranscriptionService? transcriptionService,
    Uuid? uuid,
  }) : _repository = repository,
       _pipeline = pipeline,
       _transcriptionService = transcriptionService,
       _uuid = uuid ?? const Uuid();

  final MeetingRepository _repository;
  final MeetingIntelligencePipeline _pipeline;
  final MeetingTranscriptionService? _transcriptionService;
  final Uuid _uuid;
  final List<TranscriptChunk> _finalChunks = [];
  StreamSubscription<TranscriptChunk>? _partialSubscription;
  StreamSubscription<TranscriptChunk>? _finalSubscription;
  TranscriptChunk? _lastPartialChunk;

  MeetingSessionState state = const MeetingSessionState(
    recordingState: RecordingState.idle,
  );

  Future<Meeting> startMeeting({required String title}) async {
    await _cancelTranscriptSubscriptions();
    final meeting = Meeting(
      id: _uuid.v4(),
      title: title.trim().isEmpty ? 'Untitled meeting' : title.trim(),
      startedAt: DateTime.now(),
      state: MeetingState.recording,
    );
    _finalChunks.clear();
    _lastPartialChunk = null;
    await _repository.saveMeeting(meeting);
    state = state.copyWith(
      recordingState: RecordingState.recording,
      meeting: meeting,
      finalTranscript: '',
      partialTranscript: '',
    );
    notifyListeners();

    try {
      await _transcriptionService?.startRealtimeTranscription(meeting: meeting);
      _listenForTranscriptEvents();
    } catch (error) {
      state = state.copyWith(
        recordingState: RecordingState.failed,
        errorMessage: 'Realtime transcription could not start: $error',
      );
      notifyListeners();
    }
    return meeting;
  }

  void applyTranscriptEvent(TranscriptChunk chunk) {
    final meeting = state.meeting;
    if (meeting == null) {
      state = state.copyWith(
        recordingState: RecordingState.failed,
        errorMessage:
            'Cannot accept transcript events before a meeting starts.',
      );
      return;
    }
    final scopedChunk = chunk.copyWith(meetingId: meeting.id);
    if (scopedChunk.isFinal) {
      _finalChunks.add(scopedChunk);
      _lastPartialChunk = null;
      state = state.copyWith(
        finalTranscript: _finalTranscriptText(),
        partialTranscript: '',
      );
      notifyListeners();
      return;
    }
    _lastPartialChunk = scopedChunk;
    state = state.copyWith(partialTranscript: scopedChunk.text);
    notifyListeners();
  }

  Future<void> pauseMeeting() async {
    _ensureActive();
    await _transcriptionService?.pauseRealtimeTranscription();
    state = state.copyWith(recordingState: RecordingState.paused);
    notifyListeners();
  }

  Future<void> resumeMeeting() async {
    _ensureActive();
    await _transcriptionService?.resumeRealtimeTranscription();
    state = state.copyWith(recordingState: RecordingState.recording);
    notifyListeners();
  }

  Future<MeetingIntelligence> stopMeeting() async {
    final meeting = _ensureActive();
    await _transcriptionService?.stopRealtimeTranscription();
    await _cancelTranscriptSubscriptions();
    _promotePendingPartialChunk();
    final completed = meeting.copyWith(
      state: MeetingState.completed,
      endedAt: DateTime.now(),
      duration: DateTime.now().difference(meeting.startedAt),
    );
    await _repository.saveMeeting(completed);
    for (final chunk in _finalChunks) {
      await _repository.saveTranscriptChunk(chunk);
    }
    final intelligence = await _pipeline.process(
      meeting: completed,
      chunks: _finalChunks,
    );
    await _repository.saveIntelligence(intelligence);
    state = state.copyWith(
      recordingState: RecordingState.stopped,
      meeting: completed,
      finalTranscript: _finalTranscriptText(),
      partialTranscript: '',
    );
    notifyListeners();
    return intelligence;
  }

  Future<void> cancelMeeting() async {
    final meeting = state.meeting;
    await _transcriptionService?.stopRealtimeTranscription();
    await _cancelTranscriptSubscriptions();
    if (meeting != null) {
      await _repository.saveMeeting(
        meeting.copyWith(
          state: MeetingState.cancelled,
          endedAt: DateTime.now(),
        ),
      );
    }
    _finalChunks.clear();
    _lastPartialChunk = null;
    state = state.copyWith(
      recordingState: RecordingState.cancelled,
      finalTranscript: '',
      partialTranscript: '',
    );
    notifyListeners();
  }

  Meeting _ensureActive() {
    final meeting = state.meeting;
    if (meeting == null) {
      throw StateError('No active meeting session.');
    }
    return meeting;
  }

  void _listenForTranscriptEvents() {
    final service = _transcriptionService;
    if (service == null) return;
    _partialSubscription = service.partialTranscript().listen(
      applyTranscriptEvent,
      onError: _handleTranscriptError,
    );
    _finalSubscription = service.finalTranscript().listen(
      applyTranscriptEvent,
      onError: _handleTranscriptError,
    );
  }

  void _handleTranscriptError(Object error) {
    state = state.copyWith(
      recordingState: RecordingState.failed,
      errorMessage: 'Realtime transcription failed: $error',
    );
    notifyListeners();
  }

  void _promotePendingPartialChunk() {
    final pending = _lastPartialChunk;
    if (pending == null || pending.text.trim().isEmpty) return;
    if (_finalChunks.isNotEmpty && _finalChunks.last.text == pending.text) {
      return;
    }
    _finalChunks.add(
      pending.copyWith(id: '${pending.id}_final', isFinal: true),
    );
    _lastPartialChunk = null;
  }

  String _finalTranscriptText() {
    return _finalChunks
        .map((chunk) => chunk.text.trim())
        .where((text) => text.isNotEmpty)
        .join('\n');
  }

  Future<void> _cancelTranscriptSubscriptions() async {
    await _partialSubscription?.cancel();
    await _finalSubscription?.cancel();
    _partialSubscription = null;
    _finalSubscription = null;
  }

  @override
  void dispose() {
    unawaited(_cancelTranscriptSubscriptions());
    super.dispose();
  }
}
