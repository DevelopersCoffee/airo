import 'package:core_workers/core_workers.dart';

import '../../mind_service.dart';
import '../../whisper/api/meetings.dart' as rust;
import '../domain/meeting_export_models.dart';
import '../domain/meeting_markdown_renderer.dart';

/// Turns stored meetings into export bundles.
///
/// This is the seam #1657 and a future MoM-FFI-wiring issue land in without
/// touching the renderer: [_buildInput] is the only place that reads off
/// `MindService`, and today it can only fill [MeetingExportInput.momMarkdown]
/// and `.actionItems` with nothing, because:
///
/// - `#1657` (Stage 2, in flight as of this writing) is what puts
///   `decisions`/`action_items`/`metrics` onto the persisted `Meeting`
///   record and exposes them to Dart. Until it lands there is no Dart-side
///   action-item data to read.
/// - Saved minutes come from the scribe pipeline (`MindService.process` →
///   `llama.generateMinutes`) and are persisted on `MeetingRecord.minutes`.
///   Export reads that field today. Structured Meeting-IR action items still
///   wait on `#1657`; once they land on the persisted record, map them onto
///   [MeetingExportInput.actionItems] here — the renderer already knows what
///   to do with them.
class MeetingExportService {
  const MeetingExportService(this._mindService);

  final MindService _mindService;

  /// Same policy as everywhere else in the repo: parsing/serialization past
  /// ~50 KB moves off the main isolate via `runOffMain`
  /// (`packages/core_workers`), not a screen-local `compute()`. A hard
  /// character count on the transcript body approximates that threshold well
  /// enough — rendering markdown is proportional to input size, not content.
  static const _offMainThresholdChars = 50 * 1024;

  /// Builds the export bundle for one meeting, or `null` if it no longer
  /// exists (deleted between listing and export).
  Future<MeetingExportBundle?> exportMeeting(String meetingId) async {
    final input = await _buildInput(meetingId);
    if (input == null) return null;
    return _render(input);
  }

  /// Batch export: one bundle per meeting that still exists, same order as
  /// [meetingIds]. Missing meetings are skipped rather than failing the
  /// whole batch — the common case is "export everything", and one deleted
  /// meeting should not block the rest.
  Future<List<MeetingExportBundle>> exportMeetings(
    List<String> meetingIds,
  ) async {
    final inputs = <MeetingExportInput>[];
    for (final id in meetingIds) {
      final input = await _buildInput(id);
      if (input != null) inputs.add(input);
    }
    if (inputs.isEmpty) return const [];

    final size = inputs.fold<int>(0, (sum, i) => sum + _approximateSize(i));
    if (size > _offMainThresholdChars) {
      return runOffMain(() => composeBatchExport(inputs));
    }
    return composeBatchExport(inputs);
  }

  Future<MeetingExportInput?> _buildInput(String meetingId) async {
    final meeting = await _mindService.meeting(meetingId);
    if (meeting == null) return null;

    final doc = await _mindService.transcriptDocument(meetingId);
    final lines = _linesFrom(doc);
    final duration = _durationFrom(doc);

    final minutes = meeting.minutes.trim();

    return MeetingExportInput(
      meetingId: meeting.id,
      title: meeting.title,
      recordedAt: DateTime.fromMillisecondsSinceEpoch(
        meeting.recordedAt.toInt(),
      ),
      duration: duration,
      transcriptLines: lines,
      fallbackTranscript: meeting.transcript,
      momMarkdown: minutes.isEmpty ? null : minutes,
      // actionItems: waits on #1657 Meeting-IR persistence.
    );
  }

  static List<TranscriptExportLine> _linesFrom(
    rust.TranscriptDocumentRecord? doc,
  ) {
    if (doc == null) return const [];
    return [
      for (final segment in doc.segments)
        TranscriptExportLine(
          startMs: segment.startMs.toInt(),
          text: segment.text,
        ),
    ];
  }

  static Duration? _durationFrom(rust.TranscriptDocumentRecord? doc) {
    if (doc == null || doc.segments.isEmpty) return null;
    return Duration(milliseconds: doc.segments.last.endMs.toInt());
  }

  static int _approximateSize(MeetingExportInput input) {
    var size =
        input.fallbackTranscript.length + (input.momMarkdown?.length ?? 0);
    for (final line in input.transcriptLines) {
      size += line.text.length;
    }
    return size;
  }

  Future<MeetingExportBundle> _render(MeetingExportInput input) async {
    if (_approximateSize(input) > _offMainThresholdChars) {
      return runOffMain(() => composeMeetingExportBundle(input));
    }
    return composeMeetingExportBundle(input);
  }
}
