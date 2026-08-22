import 'meeting_ir/meeting_minutes_content.dart';
import 'meeting_title.dart';
import 'whisper/api/meetings.dart' as rust;

/// One row's worth of glanceable facts for the Scribe library.
class MeetingListMetadata {
  const MeetingListMetadata({
    required this.title,
    required this.preview,
    required this.metaLine,
  });

  final String title;
  final String preview;
  final String metaLine;
}

/// Title, a one-line preview of what was said, and a meta strip
/// (when · how long · size · speakers · extracted counts).
MeetingListMetadata meetingListMetadata(
  rust.MeetingRecord meeting, {
  int? audioBytes,
}) {
  final title = displayMeetingTitle(
    title: meeting.title,
    transcript: meeting.transcript,
  );
  return MeetingListMetadata(
    title: title,
    preview: meetingListPreview(meeting),
    metaLine: meetingMetaLine(meeting, audioBytes: audioBytes),
  );
}

/// Cheap list subtitle: a real minutes excerpt, else first action/decision,
/// else the opening of the transcript. Empty MoM templates are skipped so
/// the row does not read `# Minutes of Meeting`.
String meetingListPreview(rust.MeetingRecord meeting) {
  final minutes = meeting.minutes.trim();
  if (minutes.isNotEmpty && !isEmptyMeetingMinutes(minutes)) {
    return _oneLine(minutes);
  }
  if (meeting.actionItems.isNotEmpty) {
    final item = meeting.actionItems.first;
    final owner = item.owner?.trim();
    return owner == null || owner.isEmpty ? item.task : '${item.task} — $owner';
  }
  if (meeting.decisions.isNotEmpty) {
    return meeting.decisions.first.statement;
  }
  return _oneLine(_flattenForPreview(meeting.transcript));
}

String meetingMetaLine(rust.MeetingRecord meeting, {int? audioBytes}) {
  final parts = <String>[
    formatMeetingRecordedAt(meeting.recordedAt),
    if (durationFromTranscript(meeting.transcript) case final duration?)
      formatMeetingDuration(duration),
    if (audioBytes != null && audioBytes > 0) formatAudioBytes(audioBytes),
    ..._speakerPart(meeting.transcript),
    ..._insightParts(meeting),
  ];
  return parts.join(' · ');
}

/// Rust stores `recorded_at` in seconds (`recorded_at_ms / 1000`).
String formatMeetingRecordedAt(BigInt recordedAt) {
  final seconds = recordedAt.toInt();
  if (seconds <= 0) return 'Just now';
  final at = DateTime.fromMillisecondsSinceEpoch(seconds * 1000);
  return _formatWhen(at, DateTime.now());
}

Duration? durationFromTranscript(String transcript) {
  final matches = RegExp(r'\[(\d{2}):(\d{2}):(\d{2})\]').allMatches(transcript);
  if (matches.isEmpty) return null;
  final last = matches.last;
  final duration = Duration(
    hours: int.parse(last.group(1)!),
    minutes: int.parse(last.group(2)!),
    seconds: int.parse(last.group(3)!),
  );
  return duration == Duration.zero ? null : duration;
}

String formatMeetingDuration(Duration duration) {
  final hours = duration.inHours;
  final minutes = duration.inMinutes % 60;
  final seconds = duration.inSeconds % 60;
  if (hours > 0) return '${hours}h ${minutes}m';
  if (minutes > 0)
    return seconds == 0 ? '${minutes}m' : '${minutes}m ${seconds}s';
  return '${seconds}s';
}

String formatAudioBytes(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) {
    return '${(bytes / 1024).toStringAsFixed(bytes < 10 * 1024 ? 1 : 0)} KB';
  }
  return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
}

int speakerCountFromTranscript(String transcript) {
  final labels = RegExp(r'\bsp(\d+)\b').allMatches(transcript);
  if (labels.isEmpty) return 0;
  return {for (final m in labels) m.group(1)!}.length;
}

List<String> _speakerPart(String transcript) {
  final count = speakerCountFromTranscript(transcript);
  if (count <= 0) return const [];
  return [count == 1 ? '1 speaker' : '$count speakers'];
}

List<String> _insightParts(rust.MeetingRecord meeting) {
  final parts = <String>[
    if (meeting.decisions.isNotEmpty)
      meeting.decisions.length == 1
          ? '1 decision'
          : '${meeting.decisions.length} decisions',
    if (meeting.actionItems.isNotEmpty)
      meeting.actionItems.length == 1
          ? '1 action'
          : '${meeting.actionItems.length} actions',
  ];
  return parts;
}

String _formatWhen(DateTime at, DateTime now) {
  final local = at.toLocal();
  final sameDay =
      local.year == now.year &&
      local.month == now.month &&
      local.day == now.day;
  final time =
      '${_pad(local.hour == 0
          ? 12
          : local.hour > 12
          ? local.hour - 12
          : local.hour)}:${_pad(local.minute)} '
      '${local.hour >= 12 ? 'PM' : 'AM'}';
  if (sameDay) return 'Today $time';
  final yesterday = now.subtract(const Duration(days: 1));
  if (local.year == yesterday.year &&
      local.month == yesterday.month &&
      local.day == yesterday.day) {
    return 'Yesterday $time';
  }
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return '${local.day} ${months[local.month - 1]} $time';
}

String _flattenForPreview(String raw) {
  return raw
      .replaceAll(RegExp(r'\[\d{2}:\d{2}:\d{2}\]'), ' ')
      .replaceAll(RegExp(r'\bsp\d+:\s*'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}

String _oneLine(String text) {
  final flat = text.replaceAll(RegExp(r'\s+'), ' ').trim();
  if (flat.length <= 140) return flat;
  return '${flat.substring(0, 140).trimRight()}…';
}

String _pad(int n) => n.toString().padLeft(2, '0');
