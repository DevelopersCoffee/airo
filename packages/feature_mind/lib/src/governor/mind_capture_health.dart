import 'package:flutter/foundation.dart';

/// Health of the optional live-intelligence pipeline. Recording is tracked
/// separately ([CaptureHealth.captureState]) because the core reliability rule
/// (spec §22) is that intelligence health can never pull recording down.
enum LiveIntelligenceHealth {
  /// Live transcript/insights running normally.
  healthy,

  /// Live output is partial or paused, but the session survives.
  degraded,

  /// Live pipeline produced nothing usable this session; recording is
  /// unaffected and the post-recording pipeline is the fallback.
  unavailable;

  String get label => switch (this) {
    LiveIntelligenceHealth.healthy => 'Healthy',
    LiveIntelligenceHealth.degraded => 'Degraded',
    LiveIntelligenceHealth.unavailable => 'Unavailable',
  };
}

/// State of the authoritative capture (the file recorder).
enum CaptureState {
  active,
  paused,
  stopped;

  String get label => switch (this) {
    CaptureState.active => 'Active',
    CaptureState.paused => 'Paused',
    CaptureState.stopped => 'Stopped',
  };
}

/// The failure classes the live pipeline must isolate (spec §3). Each declares
/// whether it touches capture at all and how far it degrades live intelligence.
enum MindLiveFailure {
  sttInitFailure,
  sttRuntimeFailure,
  modelLoadFailure,
  nativeWorkerCrash,
  malformedPcm,
  ringBufferOverflow,
  memoryAdmissionFailure,
  thermalDegradation,
  microphoneInterruption,
  audioDeviceInterruption,
  appPaused;

  /// Whether this is a capture-side event (mic/device interruption, app pause)
  /// rather than an intelligence failure. Only capture-side events may change
  /// the capture state — and only by pausing, never by discarding the file.
  bool get isCaptureEvent => switch (this) {
    MindLiveFailure.microphoneInterruption ||
    MindLiveFailure.audioDeviceInterruption ||
    MindLiveFailure.appPaused => true,
    _ => false,
  };

  /// How far live intelligence degrades. Hard failures (init/load/crash/
  /// admission) make live unavailable for the session; soft failures degrade
  /// but keep trying; capture events do not themselves degrade intelligence.
  LiveIntelligenceHealth get liveOutcome => switch (this) {
    MindLiveFailure.sttInitFailure ||
    MindLiveFailure.modelLoadFailure ||
    MindLiveFailure.nativeWorkerCrash ||
    MindLiveFailure.memoryAdmissionFailure =>
      LiveIntelligenceHealth.unavailable,
    MindLiveFailure.sttRuntimeFailure ||
    MindLiveFailure.malformedPcm ||
    MindLiveFailure.ringBufferOverflow ||
    MindLiveFailure.thermalDegradation => LiveIntelligenceHealth.degraded,
    MindLiveFailure.microphoneInterruption ||
    MindLiveFailure.audioDeviceInterruption ||
    MindLiveFailure.appPaused => LiveIntelligenceHealth.healthy,
  };

  String get message => switch (this) {
    MindLiveFailure.sttInitFailure => 'Speech engine failed to start',
    MindLiveFailure.sttRuntimeFailure => 'Speech engine error',
    MindLiveFailure.modelLoadFailure => 'Model failed to load',
    MindLiveFailure.nativeWorkerCrash => 'Live worker restarted',
    MindLiveFailure.malformedPcm => 'Audio glitch',
    MindLiveFailure.ringBufferOverflow => 'Audio buffer overflow',
    MindLiveFailure.memoryAdmissionFailure =>
      'Not enough memory for live intelligence',
    MindLiveFailure.thermalDegradation =>
      'Device hot: live intelligence reduced',
    MindLiveFailure.microphoneInterruption => 'Microphone interrupted',
    MindLiveFailure.audioDeviceInterruption => 'Audio device changed',
    MindLiveFailure.appPaused => 'App paused',
  };
}

/// Snapshot of capture + live-intelligence health. Immutable; transitions
/// return a new instance. The invariants enforced by the transition methods
/// are the spec §22 contract: a live-intelligence failure never stops capture,
/// never invalidates the recorded file, and never removes the post-recording
/// fallback.
@immutable
class CaptureHealth {
  const CaptureHealth({
    required this.captureState,
    required this.recordedFileValid,
    required this.liveIntelligence,
    required this.reasons,
  });

  /// Initial healthy state when a recording starts.
  factory CaptureHealth.recording() => const CaptureHealth(
    captureState: CaptureState.active,
    recordedFileValid: true,
    liveIntelligence: LiveIntelligenceHealth.healthy,
    reasons: [],
  );

  final CaptureState captureState;

  /// The recorded source file is intact and transcribable — the authoritative
  /// recovery artifact (spec §22).
  final bool recordedFileValid;

  final LiveIntelligenceHealth liveIntelligence;
  final List<String> reasons;

  /// Post-recording transcription/intelligence can run as long as the recorded
  /// file is valid, regardless of live-pipeline health.
  bool get postRecordingPipelineAvailable => recordedFileValid;

  bool get isLiveDegraded => liveIntelligence != LiveIntelligenceHealth.healthy;

  /// Applies a failure, preserving the capture invariants. Intelligence
  /// failures only degrade [liveIntelligence]; capture events only *pause*
  /// capture. Nothing here can set [recordedFileValid] to false.
  CaptureHealth applyFailure(MindLiveFailure failure) {
    final nextReasons = reasons.contains(failure.message)
        ? reasons
        : [...reasons, failure.message];

    if (failure.isCaptureEvent) {
      // Capture-side interruption: pause (recoverable), keep file + live state.
      return _copyWith(
        captureState: captureState == CaptureState.stopped
            ? CaptureState.stopped
            : CaptureState.paused,
        reasons: nextReasons,
      );
    }

    // Intelligence failure: degrade live only. Never downgrade a hard
    // 'unavailable' back to 'degraded'.
    final outcome = failure.liveOutcome;
    final worst = outcome.index >= liveIntelligence.index
        ? outcome
        : liveIntelligence;
    return _copyWith(liveIntelligence: worst, reasons: nextReasons);
  }

  /// Resumes capture after a recoverable interruption.
  CaptureHealth resumeCapture() => captureState == CaptureState.paused
      ? _copyWith(captureState: CaptureState.active)
      : this;

  /// Stops capture at the end of a session.
  CaptureHealth stopCapture() => _copyWith(captureState: CaptureState.stopped);

  String get recordingLine => 'Recording: ${captureState.label}';
  String get liveIntelligenceLine =>
      'Live intelligence: ${liveIntelligence.label}';

  CaptureHealth _copyWith({
    CaptureState? captureState,
    bool? recordedFileValid,
    LiveIntelligenceHealth? liveIntelligence,
    List<String>? reasons,
  }) => CaptureHealth(
    captureState: captureState ?? this.captureState,
    recordedFileValid: recordedFileValid ?? this.recordedFileValid,
    liveIntelligence: liveIntelligence ?? this.liveIntelligence,
    reasons: List.unmodifiable(reasons ?? this.reasons),
  );
}
