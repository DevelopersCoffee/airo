enum MeetingState { draft, recording, paused, completed, cancelled, failed }

enum RecordingState { idle, recording, paused, stopped, cancelled, failed }

class Meeting {
  const Meeting({
    required this.id,
    required this.title,
    required this.startedAt,
    required this.state,
    this.endedAt,
    this.duration = Duration.zero,
    this.languageCode = 'en',
    this.transcriptionPath = TranscriptionPath.onDeviceWhisper,
    this.audioMetadata,
  });

  final String id;
  final String title;
  final DateTime startedAt;
  final DateTime? endedAt;
  final Duration duration;
  final MeetingState state;
  final String languageCode;
  final TranscriptionPath transcriptionPath;
  final AudioMetadata? audioMetadata;

  Meeting copyWith({
    String? id,
    String? title,
    DateTime? startedAt,
    DateTime? endedAt,
    Duration? duration,
    MeetingState? state,
    String? languageCode,
    TranscriptionPath? transcriptionPath,
    AudioMetadata? audioMetadata,
  }) {
    return Meeting(
      id: id ?? this.id,
      title: title ?? this.title,
      startedAt: startedAt ?? this.startedAt,
      endedAt: endedAt ?? this.endedAt,
      duration: duration ?? this.duration,
      state: state ?? this.state,
      languageCode: languageCode ?? this.languageCode,
      transcriptionPath: transcriptionPath ?? this.transcriptionPath,
      audioMetadata: audioMetadata ?? this.audioMetadata,
    );
  }
}

enum TranscriptionPath { platformRecognizer, onDeviceWhisper }

class AudioMetadata {
  const AudioMetadata({
    required this.sampleRateHz,
    required this.channelCount,
    required this.codec,
    required this.filePath,
    required this.sizeBytes,
    this.sha256,
  });

  final int sampleRateHz;
  final int channelCount;
  final String codec;
  final String filePath;
  final int sizeBytes;
  final String? sha256;
}
