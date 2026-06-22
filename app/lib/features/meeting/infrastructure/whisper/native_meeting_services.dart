import 'dart:async';

import 'package:flutter/services.dart';

import '../../domain/entities/meeting.dart';
import '../../domain/entities/transcript_chunk.dart';
import '../../domain/services/meeting_service_interfaces.dart';

class NativeMeetingRecorderService implements MeetingRecorderService {
  NativeMeetingRecorderService({
    MethodChannel channel = const MethodChannel('com.airo.meeting/recorder'),
  }) : _channel = channel;

  final MethodChannel _channel;
  final StreamController<RecordingState> _recordingState =
      StreamController<RecordingState>.broadcast();
  final StreamController<double> _audioLevel =
      StreamController<double>.broadcast();
  Meeting? _activeMeeting;
  DateTime? _startedAt;

  @override
  Future<Meeting> startMeeting({required String title}) async {
    final result = await _channel.invokeMapMethod<String, Object?>(
      'startMeeting',
      {'title': title},
    );
    final id =
        result?['id'] as String? ??
        DateTime.now().microsecondsSinceEpoch.toString();
    _startedAt = DateTime.now();
    _activeMeeting = Meeting(
      id: id,
      title: title,
      startedAt: _startedAt!,
      state: MeetingState.recording,
    );
    _recordingState.add(RecordingState.recording);
    return _activeMeeting!;
  }

  @override
  Future<void> pauseMeeting() async {
    await _channel.invokeMethod<void>('pauseMeeting');
    _recordingState.add(RecordingState.paused);
  }

  @override
  Future<void> resumeMeeting() async {
    await _channel.invokeMethod<void>('resumeMeeting');
    _recordingState.add(RecordingState.recording);
  }

  @override
  Future<Meeting> stopMeeting() async {
    final active = _activeMeeting;
    if (active == null) throw StateError('No active native meeting recording.');
    final result = await _channel.invokeMapMethod<String, Object?>(
      'stopMeeting',
    );
    final endedAt = DateTime.now();
    _recordingState.add(RecordingState.stopped);
    _activeMeeting = active.copyWith(
      state: MeetingState.completed,
      endedAt: endedAt,
      duration: endedAt.difference(active.startedAt),
      audioMetadata: AudioMetadata(
        sampleRateHz: (result?['sampleRateHz'] as int?) ?? 16000,
        channelCount: (result?['channelCount'] as int?) ?? 1,
        codec: (result?['codec'] as String?) ?? 'pcm16',
        filePath: (result?['filePath'] as String?) ?? '',
        sizeBytes: (result?['sizeBytes'] as int?) ?? 0,
        sha256: result?['sha256'] as String?,
      ),
    );
    return _activeMeeting!;
  }

  @override
  Future<void> cancelMeeting() async {
    await _channel.invokeMethod<void>('cancelMeeting');
    _recordingState.add(RecordingState.cancelled);
    _activeMeeting = null;
  }

  @override
  Duration recordingDuration() {
    final start = _startedAt;
    return start == null ? Duration.zero : DateTime.now().difference(start);
  }

  @override
  Stream<RecordingState> recordingState() => _recordingState.stream;

  @override
  Stream<double> audioLevel() => _audioLevel.stream;
}

class NativeMeetingTranscriptionService implements MeetingTranscriptionService {
  NativeMeetingTranscriptionService({
    MethodChannel channel = const MethodChannel(
      'com.airo.meeting/transcription',
    ),
    EventChannel eventChannel = const EventChannel(
      'com.airo.meeting/transcription_events',
    ),
  }) : _channel = channel,
       _eventChannel = eventChannel;

  final MethodChannel _channel;
  final EventChannel _eventChannel;
  Stream<TranscriptChunk>? _events;

  @override
  Future<void> startRealtimeTranscription({required Meeting meeting}) async {
    _events = _eventChannel.receiveBroadcastStream().map(_chunkFromEvent);
    await _channel.invokeMethod<void>('startRealtimeTranscription', {
      'meetingId': meeting.id,
      'languageCode': meeting.languageCode,
    });
  }

  @override
  Future<void> pauseRealtimeTranscription() async {
    await _channel.invokeMethod<void>('pauseRealtimeTranscription');
  }

  @override
  Future<void> resumeRealtimeTranscription() async {
    await _channel.invokeMethod<void>('resumeRealtimeTranscription');
  }

  @override
  Future<void> stopRealtimeTranscription() =>
      _channel.invokeMethod<void>('stopRealtimeTranscription');

  @override
  Stream<TranscriptChunk> partialTranscript() =>
      (_events ?? const Stream.empty()).where((chunk) => !chunk.isFinal);

  @override
  Stream<TranscriptChunk> finalTranscript() =>
      (_events ?? const Stream.empty()).where((chunk) => chunk.isFinal);

  TranscriptChunk _chunkFromEvent(Object? event) {
    final map = Map<String, Object?>.from(event as Map);
    return TranscriptChunk(
      id: map['id'] as String,
      meetingId: map['meetingId'] as String,
      text: map['text'] as String,
      start: Duration(milliseconds: map['startMs'] as int),
      end: Duration(milliseconds: map['endMs'] as int),
      isFinal: map['isFinal'] as bool? ?? false,
      speakerLabel: map['speakerLabel'] as String?,
      confidence: (map['confidence'] as num?)?.toDouble() ?? 1,
    );
  }
}

class FallbackMeetingTranscriptionService
    implements MeetingTranscriptionService {
  FallbackMeetingTranscriptionService({
    MeetingTranscriptionService? primary,
    MeetingTranscriptionService? fallback,
  }) : _primary = primary ?? NativeMeetingTranscriptionService(),
       _fallback = fallback ?? const LocalPreviewMeetingTranscriptionService();

  final MeetingTranscriptionService _primary;
  final MeetingTranscriptionService _fallback;
  MeetingTranscriptionService? _active;

  @override
  Future<void> startRealtimeTranscription({required Meeting meeting}) async {
    try {
      await _primary.startRealtimeTranscription(meeting: meeting);
      _active = _primary;
    } on MissingPluginException {
      await _fallback.startRealtimeTranscription(meeting: meeting);
      _active = _fallback;
    } on PlatformException catch (error) {
      if (error.code == 'speech_recognizer_unavailable') {
        await _fallback.startRealtimeTranscription(meeting: meeting);
        _active = _fallback;
        return;
      }
      rethrow;
    }
  }

  @override
  Future<void> pauseRealtimeTranscription() =>
      _active?.pauseRealtimeTranscription() ?? Future.value();

  @override
  Future<void> resumeRealtimeTranscription() =>
      _active?.resumeRealtimeTranscription() ?? Future.value();

  @override
  Future<void> stopRealtimeTranscription() async {
    await _active?.stopRealtimeTranscription();
    _active = null;
  }

  @override
  Stream<TranscriptChunk> partialTranscript() =>
      (_active ?? _fallback).partialTranscript();

  @override
  Stream<TranscriptChunk> finalTranscript() =>
      (_active ?? _fallback).finalTranscript();
}

class LocalPreviewMeetingTranscriptionService
    implements MeetingTranscriptionService {
  const LocalPreviewMeetingTranscriptionService();

  static final StreamController<TranscriptChunk> _partialTranscript =
      StreamController<TranscriptChunk>.broadcast(sync: true);
  static final StreamController<TranscriptChunk> _finalTranscript =
      StreamController<TranscriptChunk>.broadcast(sync: true);
  static final List<String> _sampleTranscript = [
    'Decision: keep Live Notes offline-first for the first release.',
    'Action: Uday will validate realtime transcript quality on Android and iOS.',
    'Risk: native Whisper models need a visible download and storage check.',
    'Next step: replace the local preview stream with platform Whisper events.',
  ];
  static Timer? _timer;
  static Meeting? _meeting;
  static int _sentenceIndex = 0;
  static bool _emitFinalNext = false;
  static bool _isPaused = false;
  static TranscriptChunk? _lastPartial;

  @override
  Future<void> startRealtimeTranscription({required Meeting meeting}) async {
    await stopRealtimeTranscription();
    _meeting = meeting;
    _sentenceIndex = 0;
    _emitFinalNext = false;
    _isPaused = false;
    _lastPartial = null;
    _timer = Timer.periodic(const Duration(seconds: 2), (_) => _emitChunk());
    _emitChunk();
  }

  @override
  Future<void> pauseRealtimeTranscription() async {
    _isPaused = true;
  }

  @override
  Future<void> resumeRealtimeTranscription() async {
    _isPaused = false;
    _emitChunk();
  }

  @override
  Future<void> stopRealtimeTranscription() async {
    _timer?.cancel();
    _timer = null;
    final pending = _lastPartial;
    if (pending != null) {
      _finalTranscript.add(
        pending.copyWith(id: '${pending.id}_final', isFinal: true),
      );
    }
    _lastPartial = null;
    _meeting = null;
    _isPaused = false;
  }

  @override
  Stream<TranscriptChunk> partialTranscript() => _partialTranscript.stream;

  @override
  Stream<TranscriptChunk> finalTranscript() => _finalTranscript.stream;

  static void _emitChunk() {
    final meeting = _meeting;
    if (meeting == null || _isPaused) return;

    final text = _sampleTranscript[_sentenceIndex % _sampleTranscript.length];
    final start = Duration(seconds: _sentenceIndex * 8);
    final end = start + const Duration(seconds: 8);

    if (_emitFinalNext) {
      final chunk = TranscriptChunk(
        id: 'preview_${_sentenceIndex}_final',
        meetingId: meeting.id,
        text: text,
        start: start,
        end: end,
        isFinal: true,
      );
      _finalTranscript.add(chunk);
      _lastPartial = null;
      _sentenceIndex += 1;
      _emitFinalNext = false;
      return;
    }

    final partialText = _partialText(text);
    final chunk = TranscriptChunk(
      id: 'preview_${_sentenceIndex}_partial',
      meetingId: meeting.id,
      text: partialText,
      start: start,
      end: end,
      isFinal: false,
      confidence: 0.95,
    );
    _lastPartial = chunk.copyWith(text: text);
    _partialTranscript.add(chunk);
    _emitFinalNext = true;
  }

  static String _partialText(String text) {
    final words = text.split(' ');
    final take = (words.length * 0.65).ceil().clamp(1, words.length);
    return words.take(take).join(' ');
  }
}
