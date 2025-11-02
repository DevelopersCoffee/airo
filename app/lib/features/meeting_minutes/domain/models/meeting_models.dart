import 'package:equatable/equatable.dart';

/// Meeting participant
class Participant extends Equatable {
  final String id;
  final String name;
  final String? avatarUrl;

  const Participant({required this.id, required this.name, this.avatarUrl});

  @override
  List<Object?> get props => [id, name, avatarUrl];
}

/// Meeting transcript segment
class TranscriptSegment extends Equatable {
  final String id;
  final Participant speaker;
  final String text;
  final Duration startTime;
  final Duration endTime;

  const TranscriptSegment({
    required this.id,
    required this.speaker,
    required this.text,
    required this.startTime,
    required this.endTime,
  });

  @override
  List<Object?> get props => [id, speaker, text, startTime, endTime];
}

/// Meeting minutes summary
class MeetingMinutes extends Equatable {
  final String id;
  final String title;
  final DateTime date;
  final List<Participant> participants;
  final List<TranscriptSegment> transcript;
  final String summary;
  final List<String> actionItems;
  final List<String> decisions;
  final String? recordingUrl;

  const MeetingMinutes({
    required this.id,
    required this.title,
    required this.date,
    required this.participants,
    required this.transcript,
    required this.summary,
    required this.actionItems,
    required this.decisions,
    this.recordingUrl,
  });

  @override
  List<Object?> get props => [
    id,
    title,
    date,
    participants,
    transcript,
    summary,
    actionItems,
    decisions,
    recordingUrl,
  ];
}

/// Meeting recording state
enum RecordingState { idle, recording, processing, completed, error }

/// Meeting recording model
class MeetingRecording extends Equatable {
  final String id;
  final String title;
  final DateTime startTime;
  final Duration duration;
  final RecordingState state;
  final String? filePath;
  final String? errorMessage;

  const MeetingRecording({
    required this.id,
    required this.title,
    required this.startTime,
    required this.duration,
    required this.state,
    this.filePath,
    this.errorMessage,
  });

  @override
  List<Object?> get props => [
    id,
    title,
    startTime,
    duration,
    state,
    filePath,
    errorMessage,
  ];
}
