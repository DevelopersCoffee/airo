/// Model download progress tracking.
///
/// Contains progress information for model downloads with speed and ETA.
library;

import 'package:meta/meta.dart';

/// Status of a model download operation.
enum ModelDownloadStatus {
  /// Download is queued.
  pending,

  /// Download is in progress.
  downloading,

  /// Download is paused.
  paused,

  /// Download completed successfully.
  completed,

  /// Download failed.
  failed,

  /// Download was cancelled.
  cancelled,

  /// Verifying file integrity.
  verifying,
}

/// Progress of a model download operation.
@immutable
class ModelDownloadProgress {
  const ModelDownloadProgress({
    required this.modelId,
    required this.totalBytes,
    required this.downloadedBytes,
    required this.status,
    this.speedBytesPerSecond = 0,
    this.startTime,
    this.error,
  });

  /// The model being downloaded.
  final String modelId;

  /// Total size in bytes.
  final int totalBytes;

  /// Bytes downloaded so far.
  final int downloadedBytes;

  /// Current download status.
  final ModelDownloadStatus status;

  /// Download speed in bytes per second.
  final double speedBytesPerSecond;

  /// Time when download started.
  final DateTime? startTime;

  /// Error message if download failed.
  final String? error;

  /// Progress as a percentage (0.0 - 1.0).
  double get progress => totalBytes > 0 ? downloadedBytes / totalBytes : 0.0;

  /// Progress as a percentage (0 - 100).
  int get progressPercent => (progress * 100).round();

  /// Whether the download is complete.
  bool get isComplete => status == ModelDownloadStatus.completed;

  /// Whether the download failed.
  bool get isFailed => status == ModelDownloadStatus.failed;

  /// Whether the download is in progress.
  bool get isInProgress => status == ModelDownloadStatus.downloading;

  /// Estimated time remaining in seconds.
  int? get estimatedSecondsRemaining {
    if (speedBytesPerSecond <= 0 || isComplete) return null;
    final remaining = totalBytes - downloadedBytes;
    return (remaining / speedBytesPerSecond).round();
  }

  /// Formatted download speed (e.g., "2.5 MB/s").
  String get speedDisplay {
    if (speedBytesPerSecond < 1024) {
      return '${speedBytesPerSecond.round()} B/s';
    } else if (speedBytesPerSecond < 1024 * 1024) {
      return '${(speedBytesPerSecond / 1024).toStringAsFixed(1)} KB/s';
    } else {
      return '${(speedBytesPerSecond / (1024 * 1024)).toStringAsFixed(1)} MB/s';
    }
  }

  /// Formatted ETA (e.g., "5 min remaining" or "2:30 remaining").
  String? get etaDisplay {
    final seconds = estimatedSecondsRemaining;
    if (seconds == null) return null;

    if (seconds < 60) {
      return '${seconds}s remaining';
    } else if (seconds < 3600) {
      final minutes = seconds ~/ 60;
      final secs = seconds % 60;
      return '${minutes}m ${secs}s remaining';
    } else {
      final hours = seconds ~/ 3600;
      final minutes = (seconds % 3600) ~/ 60;
      return '${hours}h ${minutes}m remaining';
    }
  }

  /// Create a starting progress.
  factory ModelDownloadProgress.starting(String modelId, int totalBytes) {
    return ModelDownloadProgress(
      modelId: modelId,
      totalBytes: totalBytes,
      downloadedBytes: 0,
      status: ModelDownloadStatus.pending,
      startTime: DateTime.now(),
    );
  }

  /// Create a completed progress.
  factory ModelDownloadProgress.completed(String modelId, int totalBytes) {
    return ModelDownloadProgress(
      modelId: modelId,
      totalBytes: totalBytes,
      downloadedBytes: totalBytes,
      status: ModelDownloadStatus.completed,
    );
  }

  /// Create a failed progress.
  factory ModelDownloadProgress.failed(String modelId, String error) {
    return ModelDownloadProgress(
      modelId: modelId,
      totalBytes: 0,
      downloadedBytes: 0,
      status: ModelDownloadStatus.failed,
      error: error,
    );
  }

  ModelDownloadProgress copyWith({
    String? modelId,
    int? totalBytes,
    int? downloadedBytes,
    ModelDownloadStatus? status,
    double? speedBytesPerSecond,
    DateTime? startTime,
    String? error,
  }) {
    return ModelDownloadProgress(
      modelId: modelId ?? this.modelId,
      totalBytes: totalBytes ?? this.totalBytes,
      downloadedBytes: downloadedBytes ?? this.downloadedBytes,
      status: status ?? this.status,
      speedBytesPerSecond: speedBytesPerSecond ?? this.speedBytesPerSecond,
      startTime: startTime ?? this.startTime,
      error: error ?? this.error,
    );
  }
}
