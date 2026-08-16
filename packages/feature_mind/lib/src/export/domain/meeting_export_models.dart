import 'package:flutter/foundation.dart';

import '../../speaker/meeting_speaker_registry.dart';

/// One line of a rendered transcript body: the audio timestamp it started at,
/// and the words said in that window.
///
/// Deliberately not `rust.TranscriptSegmentRecord` — the renderer in this
/// directory is pure Dart with no Rust import, so it stays testable without a
/// native library and reusable the day transcript storage changes shape.
@immutable
class TranscriptExportLine {
  const TranscriptExportLine({
    required this.startMs,
    required this.text,
    this.speakerLabel,
  });

  /// Milliseconds from the start of the recording.
  final int startMs;
  final String text;

  /// Diarization label (`sp0`, `sp1`, …) when persisted on the segment.
  final String? speakerLabel;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TranscriptExportLine &&
          startMs == other.startMs &&
          text == other.text &&
          speakerLabel == other.speakerLabel;

  @override
  int get hashCode => Object.hash(startMs, text, speakerLabel);
}

/// A task pulled out of a meeting, shaped for markdown export.
///
/// Deliberately not `airo_mind_meeting`'s `ActionItem` — that type lives on
/// `MeetingIr` (Rust-only; `rust/airo_mind_meeting` is an `rlib`, not yet
/// wired through FFI) and, once it is, will not reach Dart until #1657's
/// `Meeting.action_items` field lands. This is the shape the renderer needs;
/// mapping the real type onto this one is the whole connective change (see
/// `meeting_export_service.dart`).
@immutable
class ExportActionItem {
  const ExportActionItem({
    required this.task,
    this.owner,
    this.due,
    this.status,
  });

  final String task;
  final String? owner;
  final String? due;
  final String? status;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ExportActionItem &&
          task == other.task &&
          owner == other.owner &&
          due == other.due &&
          status == other.status;

  @override
  int get hashCode => Object.hash(task, owner, due, status);
}

/// Everything the renderer needs for one meeting. Built by
/// `MeetingExportService` from `MindService`'s records; consumed only by pure
/// functions in `meeting_markdown_renderer.dart`.
@immutable
class MeetingExportInput {
  const MeetingExportInput({
    required this.meetingId,
    required this.title,
    required this.recordedAt,
    this.duration,
    this.transcriptLines = const [],
    this.fallbackTranscript = '',
    this.momMarkdown,
    this.actionItems = const [],
    this.speakerRegistry = MeetingSpeakerRegistry.empty,
  });

  final String meetingId;
  final String title;
  final DateTime recordedAt;

  /// Null when no transcript document exists to derive it from (a meeting
  /// saved before `#1629`, or one whose document has no segments).
  final Duration? duration;

  /// Timestamped lines, when a `transcript.json` document is available.
  final List<TranscriptExportLine> transcriptLines;

  /// The flat transcript string every `MeetingRecord` carries. Used when
  /// [transcriptLines] is empty, so a pre-`#1629` meeting still exports —
  /// without timestamps, which is the honest degradation, not a blocker.
  final String fallbackTranscript;

  /// Minutes-of-Meeting markdown from the saved meeting record (scribe pipeline
  /// output). Null when the meeting was saved before minutes ran or generation
  /// produced nothing. Structured action items may still arrive separately via
  /// [actionItems] once `#1657` lands.
  final String? momMarkdown;

  /// A standalone action-item list, used only when there is no
  /// [momMarkdown] to carry its own table (or the caller wants a
  /// dedicated `action-items.md`, e.g. for piping into a task manager).
  final List<ExportActionItem> actionItems;

  /// User-assigned speaker names and merge aliases for export rendering.
  final MeetingSpeakerRegistry speakerRegistry;
}

/// A folder-per-meeting export: a stable folder name and the markdown files
/// that go in it (`transcript.md` always; `mom.md` and/or `action-items.md`
/// when the data exists).
@immutable
class MeetingExportBundle {
  const MeetingExportBundle({required this.folderName, required this.files});

  final String folderName;

  /// File name -> markdown contents. Ordered (insertion order preserved by
  /// `Map` in Dart) so `transcript.md` renders/saves before `mom.md`.
  final Map<String, String> files;
}
