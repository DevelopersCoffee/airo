import 'dart:async';

import '../../bridges/mind_speech_bridge.dart';
import '../../whisper/api/meetings.dart' as rust;
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
    MeetingLivePcmShim? pcmShim,
    this.onTranscriptChanged,
  }) : _speech = speechBridge ?? const RustMindSpeechBridge(),
       _pcmShim = pcmShim ?? MeetingLivePcmShim();

  final MindSpeechBridge _speech;
  final MeetingLivePcmShim _pcmShim;
  final void Function()? onTranscriptChanged;

  StreamSubscription<TranscriptEvent>? _eventsSub;
  Completer<MeetingLiveSessionResult>? _readyCompleter;
  String? _sessionId;

  String? get partialText => _partialText;
  List<TranscriptSegment> get stableSegments =>
      List<TranscriptSegment>.unmodifiable(_stableSegments);

  String? _partialText;
  final List<TranscriptSegment> _stableSegments = [];

  Future<void> start({
    required String meetingId,
    String? language,
  }) async {
    _sessionId = meetingId;
    _readyCompleter = Completer<MeetingLiveSessionResult>();
    _partialText = null;
    _stableSegments.clear();

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

  void pause() {
    final id = _sessionId;
    if (id == null) return;
    _speech.pauseLiveSession(sessionId: id);
  }

  void resume() {
    final id = _sessionId;
    if (id == null) return;
    _speech.resumeLiveSession(sessionId: id);
  }

  Future<MeetingLiveSessionResult> finish() async {
    final id = _sessionId;
    if (id == null) {
      throw StateError('Live session was not started.');
    }
    await _pcmShim.stop();
    await _speech.stopLiveSession(sessionId: id);
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
  }

  Future<void> dispose() async {
    await cancel();
    await _pcmShim.dispose();
  }

  void _onEvent(TranscriptEvent event) {
    switch (event) {
      case TranscriptEventDelta(:final delta):
        switch (delta.state) {
          case rust.TranscriptSegmentStateWire.partial:
            _partialText = delta.text;
          case rust.TranscriptSegmentStateWire.stable:
            _partialText = null;
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
    }
    onTranscriptChanged?.call();
  }
}
