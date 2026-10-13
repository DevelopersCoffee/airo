import 'download_models.dart';

/// Metrics snapshot summarizing background download telemetry.
class AiroDownloadTelemetrySnapshot {
  const AiroDownloadTelemetrySnapshot({
    required this.totalInitiated,
    required this.totalCompleted,
    required this.totalFailed,
    required this.totalCancelled,
    required this.totalBytesDownloaded,
    required this.averageSpeedBytesPerSecond,
    required this.failureCodeCounts,
    required this.retryAttemptsCount,
  });

  final int totalInitiated;
  final int totalCompleted;
  final int totalFailed;
  final int totalCancelled;
  final int totalBytesDownloaded;
  final double averageSpeedBytesPerSecond;
  final Map<DownloadFailureCode, int> failureCodeCounts;
  final int retryAttemptsCount;

  /// Diagnostic map export for analytics logging.
  Map<String, dynamic> toMap() {
    return {
      'totalInitiated': totalInitiated,
      'totalCompleted': totalCompleted,
      'totalFailed': totalFailed,
      'totalCancelled': totalCancelled,
      'totalBytesDownloaded': totalBytesDownloaded,
      'averageSpeedBytesPerSecond': averageSpeedBytesPerSecond,
      'failureCodeCounts': failureCodeCounts.map(
        (code, count) => MapEntry(code.name, count),
      ),
      'retryAttemptsCount': retryAttemptsCount,
    };
  }
}

/// Logger tracking download success, failure, speed, and retry telemetry.
class AiroDownloadTelemetryLogger {
  int _initiatedCount = 0;
  int _completedCount = 0;
  int _failedCount = 0;
  int _cancelledCount = 0;
  int _totalBytesDownloaded = 0;
  int _retryAttemptsCount = 0;

  final List<double> _speedSamples = [];
  final Map<DownloadFailureCode, int> _failureCodeCounts = {};

  /// Records download request initiation.
  void recordInitiated(DownloadArtifactRequest request) {
    _initiatedCount++;
  }

  /// Updates telemetry from download progress events.
  void recordProgress(DownloadProgress progress) {
    _totalBytesDownloaded = progress.downloadedBytes;

    if (progress.speedBytesPerSecond > 0) {
      _speedSamples.add(progress.speedBytesPerSecond);
      if (_speedSamples.length > 100) {
        _speedSamples.removeAt(0);
      }
    }

    if (progress.retryCount > 0) {
      _retryAttemptsCount++;
    }

    if (progress.status == DownloadStatus.completed) {
      _completedCount++;
    } else if (progress.status == DownloadStatus.cancelled) {
      _cancelledCount++;
    } else if (progress.status == DownloadStatus.failed) {
      _failedCount++;
      final failure = progress.failure;
      if (failure != null) {
        _failureCodeCounts[failure.code] =
            (_failureCodeCounts[failure.code] ?? 0) + 1;
      }
    }
  }

  /// Calculates average download transfer speed across recorded samples.
  double get averageSpeedBytesPerSecond {
    if (_speedSamples.isEmpty) return 0.0;
    final total = _speedSamples.reduce((a, b) => a + b);
    return total / _speedSamples.length;
  }

  /// Returns current telemetry snapshot.
  AiroDownloadTelemetrySnapshot getSnapshot() {
    return AiroDownloadTelemetrySnapshot(
      totalInitiated: _initiatedCount,
      totalCompleted: _completedCount,
      totalFailed: _failedCount,
      totalCancelled: _cancelledCount,
      totalBytesDownloaded: _totalBytesDownloaded,
      averageSpeedBytesPerSecond: averageSpeedBytesPerSecond,
      failureCodeCounts: Map.unmodifiable(_failureCodeCounts),
      retryAttemptsCount: _retryAttemptsCount,
    );
  }

  /// Resets collected metrics counters.
  void reset() {
    _initiatedCount = 0;
    _completedCount = 0;
    _failedCount = 0;
    _cancelledCount = 0;
    _totalBytesDownloaded = 0;
    _retryAttemptsCount = 0;
    _speedSamples.clear();
    _failureCodeCounts.clear();
  }
}
