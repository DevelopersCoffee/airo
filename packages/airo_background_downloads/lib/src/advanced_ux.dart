import 'download_models.dart';

/// Configuration for persistent native notification controls.
class DownloadNotificationConfig {
  const DownloadNotificationConfig({
    required this.titlePattern,
    this.showProgressInNotification = true,
    this.enablePauseResumeActions = true,
    this.enableCancelAction = true,
  });

  final String titlePattern;
  final bool showProgressInNotification;
  final bool enablePauseResumeActions;
  final bool enableCancelAction;
}

/// Controller for binding download events to persistent notifications.
class AiroDownloadNotificationController {
  AiroDownloadNotificationController({
    required this.config,
    this.onNotificationAction,
  });

  final DownloadNotificationConfig config;
  final void Function(String artifactId, String action)? onNotificationAction;

  final Map<String, DownloadProgress> _activeNotifications = {};

  /// Updates notification state based on latest download progress.
  void handleProgress(DownloadProgress progress) {
    if (progress.status == DownloadStatus.completed ||
        progress.status == DownloadStatus.cancelled) {
      _activeNotifications.remove(progress.artifactId);
    } else {
      _activeNotifications[progress.artifactId] = progress;
    }
  }

  /// Returns formatting title for active notification.
  String formatTitle(DownloadProgress progress) {
    return config.titlePattern.replaceAll('{name}', progress.artifactId);
  }

  /// Map of currently active background notifications.
  Map<String, DownloadProgress> get activeNotifications =>
      Map.unmodifiable(_activeNotifications);
}

/// Comprehensive visualizer state grouping downloads into distinct queue categories.
class AiroDownloadQueueVisualizer {
  AiroDownloadQueueVisualizer(List<DownloadProgress> entries)
    : _entries = List.unmodifiable(entries);

  final List<DownloadProgress> _entries;

  List<DownloadProgress> get downloading =>
      _entries.where((e) => e.status == DownloadStatus.downloading).toList();

  List<DownloadProgress> get queued =>
      _entries.where((e) => e.status == DownloadStatus.queued).toList();

  List<DownloadProgress> get paused =>
      _entries.where((e) => e.status == DownloadStatus.paused).toList();

  List<DownloadProgress> get completed =>
      _entries.where((e) => e.status == DownloadStatus.completed).toList();

  List<DownloadProgress> get failed =>
      _entries.where((e) => e.status == DownloadStatus.failed).toList();

  double get totalSpeedBytesPerSecond =>
      downloading.fold(0.0, (sum, item) => sum + item.speedBytesPerSecond);

  double get overallProgressFraction {
    if (_entries.isEmpty) return 0.0;
    final totalBytes = _entries.fold(0, (sum, item) => sum + item.totalBytes);
    if (totalBytes <= 0) return 0.0;
    final downloadedBytes = _entries.fold(
      0,
      (sum, item) => sum + item.downloadedBytes,
    );
    return (downloadedBytes / totalBytes).clamp(0.0, 1.0);
  }

  Duration? get estimatedRemainingTime {
    final speed = totalSpeedBytesPerSecond;
    if (speed <= 0) return null;
    final activeDownloading = downloading;
    final remainingBytes = activeDownloading.fold(
      0,
      (sum, item) => sum + (item.totalBytes - item.downloadedBytes),
    );
    if (remainingBytes <= 0) return Duration.zero;
    final seconds = remainingBytes / speed;
    return Duration(seconds: seconds.round());
  }
}
