import 'dart:async';

import '../data/audio_recorder_port.dart';
import '../data/meeting_recording_service_gateway.dart';
import '../domain/meeting_recording_state.dart';

/// Drives one meeting-capture session: start → (pause ⇄ resume)* → stop.
///
/// This is the object `MeetingCaptureScreen` holds — everything it needs to
/// know about the in-progress recording comes from [snapshots], and every
/// action it can take is one of the four methods below. It never touches
/// [AudioRecorderPort] directly, mirroring `AudioScribeConsentGate`'s "no
/// bypass to reach for" shape: this controller *is* the gate for the file
/// encoder, the same way that gate is the gate for the streaming one, and a
/// caller wanting to record a meeting has exactly one door.
///
/// Consent: this controller does not itself hold an
/// `AudioScribeConsentGate` — file capture and live dictation are different
/// screens with independent consent grants, so the caller owns the gate and
/// is expected to call `start` only after `AudioScribeConsentGate.grant` has
/// succeeded (`MeetingCaptureScreen` wires this the same way
/// `AudioScribeScreen` already does for the streaming path). Duplicating a
/// second internal gate here would just be a second door that could get out
/// of sync with the first.
class MeetingCaptureController {
  MeetingCaptureController({
    required AudioRecorderPort recorder,
    MeetingRecordingServiceGateway? serviceGateway,
    Duration tickInterval = const Duration(milliseconds: 100),
  }) : _recorder = recorder,
       _serviceGateway =
           serviceGateway ?? const NoopMeetingRecordingServiceGateway(),
       _tickInterval = tickInterval {
    _osSub = _recorder.osEvents.listen(_onOsEvent);
  }

  // Not initializing-formals (`this._recorder`, ...): the named-parameter
  // names below (`recorder`, `serviceGateway`, `tickInterval`) are the public
  // constructor API, and an initializing formal on a private field forces the
  // parameter name to match the field name -- which would make the
  // parameters unusable as named arguments from any other library. Kept
  // explicit on purpose.
  final AudioRecorderPort _recorder;
  final MeetingRecordingServiceGateway _serviceGateway;
  final Duration _tickInterval;

  final _controller = StreamController<MeetingRecordingSnapshot>.broadcast();
  StreamSubscription<RecorderOsEvent>? _osSub;
  Timer? _ticker;

  MeetingRecordingSnapshot _snapshot = MeetingRecordingSnapshot.idle;
  DateTime? _segmentStartedAt;
  int _frozenElapsedMs = 0;
  StreamSubscription<double>? _levelSub;

  Stream<MeetingRecordingSnapshot> get snapshots => _controller.stream;

  MeetingRecordingSnapshot get current => _snapshot;

  bool get isRecording =>
      _snapshot.lifecycle == MeetingRecordingLifecycle.recording;

  /// Begins encoding to [path]. Throws [StateError] if a session is already
  /// active — callers create a fresh controller (or call [reset]) per
  /// recording, the same one-consent-per-session shape
  /// `AudioScribeConsentGate.reset` documents.
  Future<void> start(String path) async {
    if (_snapshot.lifecycle != MeetingRecordingLifecycle.idle) {
      throw StateError(
        'MeetingCaptureController.start called from ${_snapshot.lifecycle.name}; '
        'a controller records one session. Create a new controller for the '
        'next one.',
      );
    }
    final granted = await _recorder.hasPermission();
    if (!granted) {
      _emit(
        _snapshot.copyWith(
          lifecycle: MeetingRecordingLifecycle.failed,
          error: 'Microphone permission was not granted.',
        ),
      );
      return;
    }
    await _serviceGateway.start(
      notificationTitle: 'Recording meeting audio',
      notificationText: 'Airo Mind is recording. Tap to return to the app.',
    );
    await _recorder.start(path);
    _frozenElapsedMs = 0;
    _segmentStartedAt = DateTime.now();
    _emit(
      MeetingRecordingSnapshot(
        lifecycle: MeetingRecordingLifecycle.recording,
        filePath: path,
        elapsedMs: 0,
      ),
    );
    _listenLevels();
    _startTicker();
  }

  Future<void> pause() async {
    if (_snapshot.lifecycle != MeetingRecordingLifecycle.recording) return;
    await _recorder.pause();
    _freezeElapsed();
    _emit(
      _snapshot.copyWith(
        lifecycle: MeetingRecordingLifecycle.paused,
        pausedByOs: false,
        amplitude: 0,
      ),
    );
    _stopTicker();
  }

  Future<void> resume() async {
    if (_snapshot.lifecycle != MeetingRecordingLifecycle.paused) return;
    await _recorder.resume();
    _segmentStartedAt = DateTime.now();
    _emit(
      _snapshot.copyWith(
        lifecycle: MeetingRecordingLifecycle.recording,
        pausedByOs: false,
      ),
    );
    _startTicker();
  }

  /// Finalises the file and returns its path, or null if nothing was ever
  /// recorded. Terminal — this controller cannot be restarted afterwards.
  Future<String?> stop() async {
    if (_snapshot.lifecycle != MeetingRecordingLifecycle.recording &&
        _snapshot.lifecycle != MeetingRecordingLifecycle.paused) {
      return null;
    }
    _freezeElapsed();
    _stopTicker();
    await _levelSub?.cancel();
    _levelSub = null;
    final path = await _recorder.stop();
    await _serviceGateway.stop();
    _emit(_snapshot.copyWith(lifecycle: MeetingRecordingLifecycle.stopped));
    return path;
  }

  void _onOsEvent(RecorderOsEvent event) {
    switch (event) {
      case RecorderOsEvent.osPaused:
        if (_snapshot.lifecycle == MeetingRecordingLifecycle.recording) {
          _freezeElapsed();
          _stopTicker();
          _emit(
            _snapshot.copyWith(
              lifecycle: MeetingRecordingLifecycle.paused,
              pausedByOs: true,
              amplitude: 0,
            ),
          );
        }
      case RecorderOsEvent.osResumed:
        if (_snapshot.lifecycle == MeetingRecordingLifecycle.paused &&
            _snapshot.pausedByOs) {
          _segmentStartedAt = DateTime.now();
          _emit(
            _snapshot.copyWith(
              lifecycle: MeetingRecordingLifecycle.recording,
              pausedByOs: false,
            ),
          );
          _startTicker();
        }
      case RecorderOsEvent.osStopped:
        // The OS ended the session entirely (rare — e.g. another app seized
        // exclusive audio input). Treat it like `stop()` without a file
        // handle to return; the caller's `stop()` call still runs and simply
        // finds nothing further to finalise.
        if (_snapshot.lifecycle == MeetingRecordingLifecycle.recording ||
            _snapshot.lifecycle == MeetingRecordingLifecycle.paused) {
          _freezeElapsed();
          _stopTicker();
          _emit(
            _snapshot.copyWith(lifecycle: MeetingRecordingLifecycle.stopped),
          );
        }
    }
  }

  void _startTicker() {
    _stopTicker();
    _ticker = Timer.periodic(_tickInterval, (_) {
      if (_snapshot.lifecycle != MeetingRecordingLifecycle.recording) return;
      _emit(_snapshot.copyWith(elapsedMs: _liveElapsedMs()));
    });
  }

  void _stopTicker() {
    _ticker?.cancel();
    _ticker = null;
  }

  void _listenLevels() {
    unawaited(_levelSub?.cancel());
    _levelSub = _recorder.levels.listen((level) {
      if (_snapshot.lifecycle != MeetingRecordingLifecycle.recording) return;
      _emit(_snapshot.copyWith(amplitude: level, elapsedMs: _liveElapsedMs()));
    });
  }

  /// Recorded duration so far. Frozen segments stay in [_frozenElapsedMs];
  /// the open segment is always `now - _segmentStartedAt`. Writing the live
  /// total back into [_snapshot.elapsedMs] must not also change that frozen
  /// base — the old ticker did, so each tick added wall time on top of an
  /// already-updated total and the display ran ahead of a real clock.
  int _liveElapsedMs() {
    final startedAt = _segmentStartedAt;
    if (startedAt == null) return _frozenElapsedMs;
    return _frozenElapsedMs +
        DateTime.now().difference(startedAt).inMilliseconds;
  }

  void _freezeElapsed() {
    _frozenElapsedMs = _liveElapsedMs();
    _segmentStartedAt = null;
    _snapshot = _snapshot.copyWith(elapsedMs: _frozenElapsedMs);
  }

  void _emit(MeetingRecordingSnapshot snapshot) {
    _snapshot = snapshot;
    if (!_controller.isClosed) _controller.add(snapshot);
  }

  Future<void> dispose() async {
    _stopTicker();
    await _levelSub?.cancel();
    await _osSub?.cancel();
    await _controller.close();
    await _recorder.dispose();
  }
}
