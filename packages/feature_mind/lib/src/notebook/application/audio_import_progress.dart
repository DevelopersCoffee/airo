import '../../capture/domain/meeting_processing_job.dart';

/// Stages shown while importing audio and waiting for on-device transcription.
enum AudioImportStage {
  resolving,
  downloading,
  staging,
  enqueueing,
  queued,
  transcribing,
  extracting,
  generating,
  saving,
  paused,
  completed,
  failed,
}

/// User-visible import + transcription status.
class AudioImportProgress {
  const AudioImportProgress({
    required this.stage,
    this.title,
    this.receivedBytes = 0,
    this.totalBytes = 0,
    this.detail,
    this.error,
  });

  final AudioImportStage stage;
  final String? title;
  final int receivedBytes;
  final int totalBytes;
  final String? detail;
  final String? error;

  bool get isTerminal =>
      stage == AudioImportStage.completed || stage == AudioImportStage.failed;

  double? get fraction {
    if (totalBytes <= 0 || receivedBytes <= 0) return null;
    return (receivedBytes / totalBytes).clamp(0.0, 1.0);
  }

  String get label => switch (stage) {
    AudioImportStage.resolving => 'Fetching video details…',
    AudioImportStage.downloading => 'Downloading audio…',
    AudioImportStage.staging => 'Saving audio…',
    AudioImportStage.enqueueing => 'Queuing for transcription…',
    AudioImportStage.queued => 'Waiting to transcribe…',
    AudioImportStage.transcribing => 'Transcribing audio…',
    AudioImportStage.extracting => 'Identifying speakers & topics…',
    AudioImportStage.generating => 'Writing minutes…',
    AudioImportStage.saving => 'Saving meeting…',
    AudioImportStage.paused => 'Paused — device is warm',
    AudioImportStage.completed => 'Transcription complete',
    AudioImportStage.failed => 'Import failed',
  };

  AudioImportProgress copyWith({
    AudioImportStage? stage,
    String? title,
    int? receivedBytes,
    int? totalBytes,
    String? detail,
    String? error,
  }) {
    return AudioImportProgress(
      stage: stage ?? this.stage,
      title: title ?? this.title,
      receivedBytes: receivedBytes ?? this.receivedBytes,
      totalBytes: totalBytes ?? this.totalBytes,
      detail: detail ?? this.detail,
      error: error ?? this.error,
    );
  }

  static AudioImportProgress fromJob(MeetingProcessingJob job) {
    final stage = switch (job.status) {
      MeetingProcessingStatus.queued => AudioImportStage.queued,
      MeetingProcessingStatus.processing => _stageFromName(job.progressStage),
      MeetingProcessingStatus.paused => AudioImportStage.paused,
      MeetingProcessingStatus.completed => AudioImportStage.completed,
      MeetingProcessingStatus.failed => AudioImportStage.failed,
    };
    return AudioImportProgress(
      stage: stage,
      title: job.title,
      detail: job.progressDetail,
      error: job.lastError,
    );
  }

  static AudioImportStage _stageFromName(String? name) {
    return switch (name) {
      'extracting' => AudioImportStage.extracting,
      'generating' => AudioImportStage.generating,
      'saving' => AudioImportStage.saving,
      'transcribing' => AudioImportStage.transcribing,
      _ => AudioImportStage.transcribing,
    };
  }
}

typedef AudioImportProgressCallback = void Function(AudioImportProgress progress);
