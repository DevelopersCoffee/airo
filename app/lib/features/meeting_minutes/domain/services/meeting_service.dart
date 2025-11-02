import '../models/meeting_models.dart';

/// Meeting service interface - WIP
/// TODO: Implement real meeting recording, transcription, and summarization
abstract interface class MeetingService {
  /// Start recording a meeting
  Future<MeetingRecording> startRecording(String title);

  /// Stop recording
  Future<MeetingRecording> stopRecording(String recordingId);

  /// Get meeting minutes by ID
  Future<MeetingMinutes?> getMeetingMinutes(String id);

  /// List all meeting minutes
  Future<List<MeetingMinutes>> listMeetingMinutes();

  /// Export meeting minutes to markdown
  Future<String> exportToMarkdown(String meetingId);

  /// Export meeting minutes to PDF
  Future<String> exportToPdf(String meetingId);

  /// Delete meeting minutes
  Future<void> deleteMeetingMinutes(String id);

  /// Dispose resources
  Future<void> dispose();
}

/// Fake meeting service for development
class FakeMeetingService implements MeetingService {
  final Map<String, MeetingRecording> _recordings = {};
  final Map<String, MeetingMinutes> _minutes = {};

  @override
  Future<MeetingRecording> startRecording(String title) async {
    final recording = MeetingRecording(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: title,
      startTime: DateTime.now(),
      duration: Duration.zero,
      state: RecordingState.recording,
    );
    _recordings[recording.id] = recording;
    return recording;
  }

  @override
  Future<MeetingRecording> stopRecording(String recordingId) async {
    final recording = _recordings[recordingId];
    if (recording == null) throw Exception('Recording not found');

    final updated = MeetingRecording(
      id: recording.id,
      title: recording.title,
      startTime: recording.startTime,
      duration: DateTime.now().difference(recording.startTime),
      state: RecordingState.processing,
      filePath: '/storage/recordings/${recording.id}.m4a',
    );
    _recordings[recordingId] = updated;
    return updated;
  }

  @override
  Future<MeetingMinutes?> getMeetingMinutes(String id) async {
    return _minutes[id];
  }

  @override
  Future<List<MeetingMinutes>> listMeetingMinutes() async {
    return _minutes.values.toList();
  }

  @override
  Future<String> exportToMarkdown(String meetingId) async {
    final minutes = _minutes[meetingId];
    if (minutes == null) throw Exception('Meeting not found');

    final buffer = StringBuffer();
    buffer.writeln('# ${minutes.title}');
    buffer.writeln('**Date:** ${minutes.date}');
    buffer.writeln();
    buffer.writeln('## Participants');
    for (final p in minutes.participants) {
      buffer.writeln('- ${p.name}');
    }
    buffer.writeln();
    buffer.writeln('## Summary');
    buffer.writeln(minutes.summary);
    buffer.writeln();
    buffer.writeln('## Action Items');
    for (final item in minutes.actionItems) {
      buffer.writeln('- [ ] $item');
    }
    buffer.writeln();
    buffer.writeln('## Decisions');
    for (final decision in minutes.decisions) {
      buffer.writeln('- $decision');
    }

    return buffer.toString();
  }

  @override
  Future<String> exportToPdf(String meetingId) async {
    // TODO: Implement PDF export
    return '/storage/exports/$meetingId.pdf';
  }

  @override
  Future<void> deleteMeetingMinutes(String id) async {
    _minutes.remove(id);
  }

  @override
  Future<void> dispose() async {
    _recordings.clear();
    _minutes.clear();
  }
}
