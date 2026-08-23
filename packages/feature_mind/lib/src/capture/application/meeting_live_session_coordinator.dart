import 'dart:async';

import '../../bridges/mind_speech_bridge.dart';
import '../../whisper/api/meetings.dart' as rust;
import '../domain/live_speaker_label.dart';
import '../domain/live_transcript_line.dart';
import '../domain/speaker_activity_span.dart';
import 'live_pcm_shim_port.dart';
import 'meeting_live_pcm_shim.dart';

/// Result of a completed live STT session.
class MeetingLiveSessionResult {
  const MeetingLiveSessionResult({
    required this.text,
    required this.segments,
  });

  final String text;
  final List<TranscriptSegment> segments;
}

/// Wires `start_live_session`, the interim PCM shim, and transcript events.
class MeetingLiveSessionCoordinator {
  MeetingLiveSessionCoordinator({
    MindSpeechBridge? speechBridge,
    LivePcmShimPort? pcmShim,
    this.onTranscriptChanged,
  }) : _speech = speechBridge ?? const RustMindSpeechBridge(),
       _pcmShim = pcmShim ?? MeetingLivePcmShim();

  final MindSpeechBridge _speech;
  final LivePcmShimPort _pcmShim;
  void Function()? onTranscriptChanged;

  StreamSubscription<TranscriptEvent>? _eventsSub;
  Completer<MeetingLiveSessionResult>? _readyCompleter;
  String? _sessionId;

  String? get partialText => _partialText;
  List<TranscriptSegment> get stableSegments =>
      List<TranscriptSegment>.unmodifiable(_stableSegments);

  /// Recent normalized amplitude samples for the live meter (oldest first).
  List<double> get amplitudeSamples =>
      List<double>.unmodifiable(_amplitudeSamples);

  /// Provisional speaker lanes derived from stable utterances (`P1`).
  List<SpeakerActivitySpan> get speakerActivitySpans {
    return [
      for (final segment in _stableSegments)
        if (parseLiveSpeakerIndex(segment.speakerLabel) case final index?)
          SpeakerActivitySpan(
            speakerIndex: index,
            startMs: segment.startMs,
            endMs: segment.endMs,
          ),
    ];
  }

  int? get activeSpeakerIndex => _activeSpeakerIndex;

  /// Recoverable degradation notice from the native live session (ring overflow, etc.).
  String? get degradedMessage => _degradedMessage;

  /// Rows for the live transcript UI (stable + optional partial tail).
  List<LiveTranscriptLine> get transcriptLines {
    final lines = <LiveTranscriptLine>[
      for (final segment in _stableSegments)
        LiveTranscriptLine(
          segmentId: segment.id,
          speakerLabel: formatLiveSpeakerLabel(segment.speakerLabel),
          text: segment.text,
          startMs: segment.startMs,
          isPartial: false,
        ),
    ];
    if (_partialText != null && _partialText!.isNotEmpty) {
      final tailSpeaker = _activeSpeakerLabel != null
          ? formatLiveSpeakerLabel(_activeSpeakerLabel)
          : _stableSegments.isNotEmpty
          ? formatLiveSpeakerLabel(_stableSegments.last.speakerLabel)
          : formatLiveSpeakerLabel(null);
      final tailStart = _stableSegments.isNotEmpty
          ? _stableSegments.last.endMs
          : 0;
      lines.add(
        LiveTranscriptLine(
          segmentId: 'partial',
          speakerLabel: tailSpeaker,
          text: _partialText!,
          startMs: tailStart,
          isPartial: true,
        ),
      );
    }
    return lines;
  }

  String? _partialText;
  String? _activeSpeakerLabel;
  int? _activeSpeakerIndex;
  String? _degradedMessage;
  final List<TranscriptSegment> _stableSegments = [];
  final List<double> _amplitudeSamples = [];

  Future<void> start({
    required String meetingId,
    String? language,
  }) async {
    _sessionId = meetingId;
    _readyCompleter = Completer<MeetingLiveSessionResult>();
    _partialText = null;
    _activeSpeakerLabel = null;
    _activeSpeakerIndex = null;
    _degradedMessage = null;
    _stableSegments.clear();
    _amplitudeSamples.clear();

    _pcmShim.onAmplitude = _onAmplitude;

    final stream = _speech.startLiveSession(
      meetingId: meetingId,
      language: language,
    );
    _eventsSub = stream.listen(_onEvent, onError: (Object error, _) {
      if (_readyCompleter?.isCompleted == false) {
        _readyCompleter!.completeError(error);
      }
    });

    await _pcmShim.start(sessionId: meetingId);
  }

  Future<void> pause() async {
    final id = _sessionId;
    if (id == null) return;
    await _pcmShim.pause();
    _speech.pauseLiveSession(sessionId: id);
  }

  Future<void> resume() async {
    final id = _sessionId;
    if (id == null) return;
    _speech.resumeLiveSession(sessionId: id);
    await _pcmShim.resume(sessionId: id);
  }

  Future<MeetingLiveSessionResult> finish({String? audioPath}) async {
    final id = _sessionId;
    if (id == null) {
      throw StateError('Live session was not started.');
    }
    await _pcmShim.stop();
    await _speech.stopLiveSession(sessionId: id, audioPath: audioPath);
    return _readyCompleter!.future;
  }

  Future<void> cancel() async {
    final id = _sessionId;
    await _pcmShim.stop();
    if (id != null) {
      _speech.cancelLiveSession(sessionId: id);
    }
    await _eventsSub?.cancel();
    _eventsSub = null;
    _sessionId = null;
    _pcmShim.onAmplitude = null;
  }

  Future<void> dispose() async {
    await cancel();
    await _pcmShim.dispose();
  }

  void _onAmplitude(double normalizedRms) {
    _amplitudeSamples.add(normalizedRms);
    const maxSamples = 12;
    if (_amplitudeSamples.length > maxSamples) {
      _amplitudeSamples.removeAt(0);
    }
    onTranscriptChanged?.call();
  }

  void _onEvent(TranscriptEvent event) {
    switch (event) {
      case TranscriptEventDelta(:final delta):
        switch (delta.state) {
          case rust.TranscriptSegmentStateWire.partial:
            _partialText = delta.text;
            if (delta.speakerLabel != null) {
              _activeSpeakerLabel = delta.speakerLabel;
              _activeSpeakerIndex = parseLiveSpeakerIndex(delta.speakerLabel);
            }
          case rust.TranscriptSegmentStateWire.stable:
            _partialText = null;
            _activeSpeakerLabel = delta.speakerLabel;
            _activeSpeakerIndex = parseLiveSpeakerIndex(delta.speakerLabel);
            _stableSegments.add(
              TranscriptSegment(
                id: delta.segmentId,
                startMs: delta.startMs.toInt(),
                endMs: delta.endMs.toInt(),
                text: delta.text,
                speakerLabel: delta.speakerLabel,
              ),
            );
          case rust.TranscriptSegmentStateWire.final_:
            final index = _stableSegments.indexWhere((s) => s.id == delta.segmentId);
            if (index >= 0) {
              _stableSegments[index] = TranscriptSegment(
                id: delta.segmentId,
                startMs: delta.startMs.toInt(),
                endMs: delta.endMs.toInt(),
                text: delta.text,
                speakerLabel: delta.speakerLabel,
              );
              _activeSpeakerLabel = delta.speakerLabel;
              _activeSpeakerIndex = parseLiveSpeakerIndex(delta.speakerLabel);
            }
        }
      case TranscriptEventTranscriptReady(:final text, :final segments):
        if (_readyCompleter?.isCompleted == false) {
          _readyCompleter!.complete(
            MeetingLiveSessionResult(text: text, segments: segments),
          );
        }
      case TranscriptEventTranscribing():
      case TranscriptEventCancelled():
        break;
      case TranscriptEventDegraded(:final message):
        _degradedMessage = message;
        break;
    }
    onTranscriptChanged?.call();
  }
}
