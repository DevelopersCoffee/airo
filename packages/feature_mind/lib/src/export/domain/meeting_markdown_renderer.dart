import '../../mind_diarization.dart';
import 'meeting_export_models.dart';
import '../../speaker/meeting_speaker_registry.dart';

/// Pure markdown rendering for meeting export (#1663).
///
/// Nothing in this file touches a plugin, `dart:io`, or a Rust binding —
/// every function here is a `String Function(...)` so it is unit-testable
/// directly, and safe to run on a worker isolate via `runOffMain`
/// (`meeting_export_service.dart` does that once a transcript crosses ~50 KB,
/// per the repo's parsing rule).

/// `123456` ms -> `[00:02:03]`. Plain text, not an app deep link: a markdown
/// file opened outside Airo has no `airo://` target to jump to (#1663 AC4 —
/// evidence links degrade gracefully).
String formatTimestamp(int ms) {
  final totalSeconds = ms ~/ 1000;
  final hours = totalSeconds ~/ 3600;
  final minutes = (totalSeconds % 3600) ~/ 60;
  final seconds = totalSeconds % 60;
  return '[${_pad2(hours)}:${_pad2(minutes)}:${_pad2(seconds)}]';
}

String _pad2(int n) => n.toString().padLeft(2, '0');

/// `1h 2m 3s` — human duration for frontmatter. Omits leading zero units so
/// a five-minute meeting reads `5m 12s`, not `0h 5m 12s`.
String formatDurationHms(Duration d) {
  final hours = d.inHours;
  final minutes = d.inMinutes % 60;
  final seconds = d.inSeconds % 60;
  final parts = <String>[
    if (hours > 0) '${hours}h',
    if (hours > 0 || minutes > 0) '${minutes}m',
    '${seconds}s',
  ];
  return parts.join(' ');
}

/// YAML frontmatter block: `date`, `duration`, `title` — the fields Obsidian
/// and most PKM tools index on out of the box (#1663 scope: "YAML
/// frontmatter (date, duration, title) for PKM/Obsidian compatibility").
String renderFrontmatter({
  required String title,
  required DateTime date,
  Duration? duration,
}) {
  final buf = StringBuffer('---\n')
    ..writeln('title: "${_escapeYaml(title)}"')
    ..writeln('date: ${date.toUtc().toIso8601String()}');
  if (duration != null) {
    buf.writeln('duration: "${formatDurationHms(duration)}"');
  }
  buf.writeln('---');
  return buf.toString();
}

String _escapeYaml(String s) =>
    s.replaceAll('\\', r'\\').replaceAll('"', r'\"');

/// `transcript.md`'s body: frontmatter, a heading, then the transcript.
///
/// Prefers timestamped [lines] (from `transcript.json`, `#1629`); falls back
/// to [fallbackTranscript] — the flat string every `MeetingRecord` carries —
/// for a meeting saved before that landed, or whose document has no
/// segments. That fallback is the honest degradation this issue's scope note
/// calls out, not a missing feature.
String renderTranscriptMarkdown({
  required String title,
  required DateTime recordedAt,
  Duration? duration,
  List<TranscriptExportLine> lines = const [],
  String fallbackTranscript = '',
  MeetingSpeakerRegistry speakerRegistry = MeetingSpeakerRegistry.empty,
  Map<String, String> globalEnrolledNames = const {},
}) {
  final buf = StringBuffer()
    ..write(
      renderFrontmatter(title: title, date: recordedAt, duration: duration),
    )
    ..writeln()
    ..writeln('# $title')
    ..writeln()
    ..writeln('## Transcript')
    ..writeln();

  if (lines.isNotEmpty) {
    for (final line in lines) {
      final text = line.text.trim();
      if (text.isEmpty) continue;
      final speakerPrefix = line.speakerLabel == null
          ? ''
          : '${_exportSpeakerPrefix(line.speakerLabel!, speakerRegistry, globalEnrolledNames)}: ';
      buf
        ..writeln('${formatTimestamp(line.startMs)} $speakerPrefix$text')
        ..writeln();
    }
  } else if (fallbackTranscript.trim().isNotEmpty) {
    buf.writeln(fallbackTranscript.trim());
  } else {
    buf.writeln('_No transcript available._');
  }

  return '${buf.toString().trimRight()}\n';
}

/// A standalone `## Action Items` table. Empty string for an empty list, so
/// callers can unconditionally append the result without a length check.
String renderActionItemsMarkdown(List<ExportActionItem> items) {
  if (items.isEmpty) return '';
  final buf = StringBuffer()
    ..writeln('## Action Items')
    ..writeln()
    ..writeln('| Task | Owner | Due | Status |')
    ..writeln('| --- | --- | --- | --- |');
  for (final item in items) {
    buf.writeln(
      '| ${item.task} | ${item.owner ?? '—'} | ${item.due ?? '—'} | '
      '${item.status ?? 'Open'} |',
    );
  }
  return buf.toString();
}

/// `2026-08-14-friday-standup` — stable, filesystem-safe, sorts
/// chronologically in a flat vault folder.
String meetingExportFolderName({
  required String title,
  required DateTime date,
}) {
  final datePart =
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';
  final slug = _slugify(title);
  return slug.isEmpty ? datePart : '$datePart-$slug';
}

String _slugify(String input) {
  final lower = input.toLowerCase().trim();
  final dashed = lower.replaceAll(RegExp(r'[^a-z0-9]+'), '-');
  return dashed.replaceAll(RegExp(r'^-+|-+$'), '');
}

/// One meeting's folder-per-meeting export bundle.
///
/// `transcript.md` is always present. `mom.md` appears only when
/// [MeetingExportInput.momMarkdown] is set — not yet reachable from Dart
/// (see the model's doc comment) — in which case any [ExportActionItem]s
/// are appended to it only if its own text has no `Action Items` section
/// already (Rust's `mom.rs` renders one itself). With no MoM but action
/// items supplied on their own, they get a dedicated `action-items.md`
/// instead of being silently dropped.
MeetingExportBundle composeMeetingExportBundle(MeetingExportInput input) {
  final files = <String, String>{
    'transcript.md': renderTranscriptMarkdown(
      title: input.title,
      recordedAt: input.recordedAt,
      duration: input.duration,
      lines: input.transcriptLines,
      fallbackTranscript: input.fallbackTranscript,
      speakerRegistry: input.speakerRegistry,
      globalEnrolledNames: input.globalEnrolledNames,
    ),
  };

  final mom = input.momMarkdown?.trim();
  if (mom != null && mom.isNotEmpty) {
    final buf =
        StringBuffer(
            renderFrontmatter(
              title: input.title,
              date: input.recordedAt,
              duration: input.duration,
            ),
          )
          ..writeln()
          ..writeln(mom);
    if (input.actionItems.isNotEmpty && !mom.contains('Action Items')) {
      buf
        ..writeln()
        ..write(renderActionItemsMarkdown(input.actionItems));
    }
    files['mom.md'] = '${buf.toString().trimRight()}\n';
  } else if (input.actionItems.isNotEmpty) {
    final buf =
        StringBuffer(
            renderFrontmatter(
              title: input.title,
              date: input.recordedAt,
              duration: input.duration,
            ),
          )
          ..writeln()
          ..write(renderActionItemsMarkdown(input.actionItems));
    files['action-items.md'] = '${buf.toString().trimRight()}\n';
  }

  return MeetingExportBundle(
    folderName: meetingExportFolderName(
      title: input.title,
      date: input.recordedAt,
    ),
    files: files,
  );
}

/// Batch export: one bundle per input, same order. A loop, not a special
/// case — kept simple per this issue's scope note on batch export.
List<MeetingExportBundle> composeBatchExport(List<MeetingExportInput> inputs) =>
    inputs.map(composeMeetingExportBundle).toList(growable: false);

String _exportSpeakerPrefix(
  String label,
  MeetingSpeakerRegistry registry,
  Map<String, String> globalEnrolledNames,
) {
  return mindSpeakerDisplayLabel(
    label,
    registry: registry,
    globalEnrolledNames: globalEnrolledNames,
  );
}
