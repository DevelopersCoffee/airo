/// State machine for in-app meeting capture (#1656).
///
/// The encoder (`AudioRecorderPort`) writes straight to disk from the moment
/// [MeetingRecordingLifecycle.recording] is entered — this enum tracks
/// *control* state (what the user, or the OS on their behalf, asked for), not
/// whether bytes are buffered anywhere. There is no `MeetingRecordingLifecycle`
/// value that means "recording, but only in memory": that state does not
/// exist in this design, which is the point (AC1 — a 90-minute recording
/// survives an app kill because the file on disk is never more than one
/// encoder buffer behind the microphone).
library;

/// Where a capture session currently is.
enum MeetingRecordingLifecycle {
  /// No session started yet.
  idle,

  /// Encoder is running and appending to the session's file.
  recording,

  /// Encoder is suspended — either the user tapped pause, or the OS paused it
  /// for them (a call arrived, Siri woke up, another app grabbed the audio
  /// session). [MeetingRecordingSnapshot.pausedByOs] tells the two apart.
  paused,

  /// Encoder has stopped and the file is finalised. Terminal.
  stopped,

  /// The encoder reported an error it cannot recover from. Terminal.
  failed,
}

/// A point-in-time read of a capture session, as the controller broadcasts it.
///
/// Deliberately does not carry raw audio bytes — those went straight to
/// [filePath] via the platform encoder and this snapshot is UI/queue state
/// only.
class MeetingRecordingSnapshot {
  const MeetingRecordingSnapshot({
    required this.lifecycle,
    required this.filePath,
    required this.elapsedMs,
    this.pausedByOs = false,
    this.error,
  });

  final MeetingRecordingLifecycle lifecycle;

  /// Where the encoder is writing. Set as soon as recording starts and never
  /// changes for the life of one session — pause/resume reuses the same file,
  /// it does not start a new one.
  final String filePath;

  /// Wall-clock milliseconds of *recorded* audio — time spent paused is
  /// excluded, so this is what ends up as the file's actual duration.
  final int elapsedMs;

  /// True when the current (or most recent) pause was triggered by the OS —
  /// an incoming call, Siri, another app taking the audio focus — rather than
  /// the user tapping the pause button. The capture screen uses this to show
  /// "Paused — call in progress" instead of the ordinary pause affordance.
  final bool pausedByOs;

  final String? error;

  MeetingRecordingSnapshot copyWith({
    MeetingRecordingLifecycle? lifecycle,
    String? filePath,
    int? elapsedMs,
    bool? pausedByOs,
    String? error,
  }) {
    return MeetingRecordingSnapshot(
      lifecycle: lifecycle ?? this.lifecycle,
      filePath: filePath ?? this.filePath,
      elapsedMs: elapsedMs ?? this.elapsedMs,
      pausedByOs: pausedByOs ?? this.pausedByOs,
      error: error ?? this.error,
    );
  }

  static const idle = MeetingRecordingSnapshot(
    lifecycle: MeetingRecordingLifecycle.idle,
    filePath: '',
    elapsedMs: 0,
  );

  @override
  String toString() =>
      'MeetingRecordingSnapshot(${lifecycle.name}, ${elapsedMs}ms, '
      'path: $filePath, pausedByOs: $pausedByOs)';
}
