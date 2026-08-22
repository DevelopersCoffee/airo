/// A queued unit of post-meeting processing (ASR + extraction), #1656 AC4.
library;

/// Where one job is in its lifecycle.
enum MeetingProcessingStatus {
  /// Waiting for its turn — either because another job is running, or
  /// because thermal/battery pressure has the whole queue paused.
  queued,

  /// Actively transcribing/extracting right now. At most one job in the
  /// queue may hold this status at a time — see
  /// `MeetingProcessingQueue`'s class doc for why.
  processing,

  /// Was `processing`, thermal pressure told the queue to stop, and it has
  /// not resumed yet. Distinct from `queued` so the UI can say "paused —
  /// device is hot" instead of just "waiting".
  paused,

  /// Finished. Terminal.
  completed,

  /// Failed in a way retrying will not fix (e.g. the audio file is gone).
  /// Terminal.
  failed;

  bool get isTerminal =>
      this == MeetingProcessingStatus.completed ||
      this == MeetingProcessingStatus.failed;
}

/// Where the audio for a processing job came from.
enum MeetingProcessingSource {
  /// In-app microphone capture.
  live,

  /// A local file the person picked (voice memo, lecture recording, …).
  upload,

  /// A remote podcast / audio URL downloaded then queued.
  podcast;

  static MeetingProcessingSource fromName(String? name) {
    return MeetingProcessingSource.values.firstWhere(
      (value) => value.name == name,
      orElse: () => MeetingProcessingSource.live,
    );
  }
}

/// One recording's trip through transcription + extraction.
///
/// Everything here is plain data so it round-trips through JSON — the whole
/// point of this type is that it survives a process death
/// (`MeetingProcessingQueue`'s persistence).
class MeetingProcessingJob {
  const MeetingProcessingJob({
    required this.id,
    required this.audioPath,
    required this.title,
    required this.enqueuedAtMs,
    this.status = MeetingProcessingStatus.queued,
    this.attempt = 0,
    this.lastError,
    this.source = MeetingProcessingSource.live,
  });

  /// Stable id for this job — the recording session id it was enqueued from.
  final String id;

  /// Path to the finalised `.m4a`/`.wav` this job transcribes.
  final String audioPath;

  /// Display title (meeting name, or a timestamp fallback).
  final String title;

  final int enqueuedAtMs;

  final MeetingProcessingStatus status;

  /// How many times this job has been picked up for processing. Used only
  /// for a bounded-retry cutoff (`MeetingProcessingQueue._maxAttempts`) —
  /// this is not exposed as a user-facing retry count.
  final int attempt;

  final String? lastError;

  /// Live capture vs uploaded file vs podcast URL. Missing from older queue
  /// files — [MeetingProcessingSource.fromName] treats that as [live].
  final MeetingProcessingSource source;

  MeetingProcessingJob copyWith({
    MeetingProcessingStatus? status,
    int? attempt,
    String? lastError,
    MeetingProcessingSource? source,
  }) {
    return MeetingProcessingJob(
      id: id,
      audioPath: audioPath,
      title: title,
      enqueuedAtMs: enqueuedAtMs,
      status: status ?? this.status,
      attempt: attempt ?? this.attempt,
      lastError: lastError ?? this.lastError,
      source: source ?? this.source,
    );
  }

  Map<String, Object?> toJson() => {
    'id': id,
    'audioPath': audioPath,
    'title': title,
    'enqueuedAtMs': enqueuedAtMs,
    'status': status.name,
    'attempt': attempt,
    'lastError': lastError,
    'source': source.name,
  };

  static MeetingProcessingJob fromJson(Map<String, Object?> json) {
    return MeetingProcessingJob(
      id: json['id']! as String,
      audioPath: json['audioPath']! as String,
      title: json['title']! as String,
      enqueuedAtMs: json['enqueuedAtMs']! as int,
      status: MeetingProcessingStatus.values.firstWhere(
        (s) => s.name == json['status'],
        orElse: () => MeetingProcessingStatus.queued,
      ),
      attempt: json['attempt'] as int? ?? 0,
      lastError: json['lastError'] as String?,
      source: MeetingProcessingSource.fromName(json['source'] as String?),
    );
  }
}
