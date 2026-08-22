/// A queued unit of post-meeting processing (ASR + extraction), #1656 AC4.
library;

import 'package:feature_mind/src/bridges/mind_speech_bridge.dart';

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
    this.completedTranscript,
    this.completedSegments,
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

  /// When set, the ASR step is skipped — live transcription already produced
  /// these (`ADR-0025` live-only mode).
  final String? completedTranscript;

  final List<TranscriptSegment>? completedSegments;

  bool get hasCompletedTranscript =>
      completedTranscript != null && completedSegments != null;

  MeetingProcessingJob copyWith({
    MeetingProcessingStatus? status,
    int? attempt,
    String? lastError,
    MeetingProcessingSource? source,
    String? completedTranscript,
    List<TranscriptSegment>? completedSegments,
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
      completedTranscript: completedTranscript ?? this.completedTranscript,
      completedSegments: completedSegments ?? this.completedSegments,
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
    if (completedTranscript != null) 'completedTranscript': completedTranscript,
    if (completedSegments != null)
      'completedSegments': completedSegments!
          .map(
            (s) => {
              'id': s.id,
              'startMs': s.startMs,
              'endMs': s.endMs,
              'text': s.text,
              'speakerLabel': s.speakerLabel,
            },
          )
          .toList(growable: false),
  };

  static MeetingProcessingJob fromJson(Map<String, Object?> json) {
    final rawSegments = json['completedSegments'] as List<Object?>?;
    List<TranscriptSegment>? segments;
    if (rawSegments != null) {
      segments = rawSegments.map((entry) {
        final map = entry! as Map<Object?, Object?>;
        return TranscriptSegment(
          id: map['id']! as String,
          startMs: map['startMs']! as int,
          endMs: map['endMs']! as int,
          text: map['text']! as String,
          speakerLabel: map['speakerLabel'] as String?,
        );
      }).toList(growable: false);
    }
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
      completedTranscript: json['completedTranscript'] as String?,
      completedSegments: segments,
    );
  }
}
