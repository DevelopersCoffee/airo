import 'dart:async';

import 'background_downloads.dart';
import 'download_models.dart';

/// Network connection constraint mode for background transfers.
enum NetworkConstraint { any, wifiOnly, unmetered }

/// Evaluates network constraints before starting or resuming downloads.
class AiroNetworkConstraintManager {
  const AiroNetworkConstraintManager({
    this.requiredConstraint = NetworkConstraint.wifiOnly,
  });

  final NetworkConstraint requiredConstraint;

  /// Checks whether download should proceed given current network connection state.
  bool shouldAllowDownload({required bool isConnected, required bool isWifi}) {
    if (!isConnected) return false;
    if (requiredConstraint == NetworkConstraint.wifiOnly && !isWifi) {
      return false;
    }
    return true;
  }
}

/// Checks available disk storage before initiating download requests.
class AiroStorageConstraintManager {
  const AiroStorageConstraintManager({
    this.safetyBufferBytes = 50 * 1024 * 1024, // 50MB safety buffer
  });

  final int safetyBufferBytes;

  /// Evaluates whether sufficient storage space exists for an artifact.
  Future<bool> hasSufficientStorage({
    required BackgroundDownloads downloader,
    required int expectedBytes,
  }) async {
    final availableBytes = await downloader.getAvailableBytes();
    if (availableBytes == null) return true; // Fail open if unknown
    return availableBytes >= (expectedBytes + safetyBufferBytes);
  }
}

/// Automatic retry policy with exponential backoff for recoverable transport failures.
class AiroAutoRetryScheduler {
  AiroAutoRetryScheduler({
    required this.downloader,
    this.maxRetryCount = 3,
    this.retryDelays = const [
      Duration(seconds: 5),
      Duration(seconds: 15),
      Duration(seconds: 30),
    ],
  });

  final BackgroundDownloads downloader;
  final int maxRetryCount;
  final List<Duration> retryDelays;

  final Map<String, int> _retryAttempts = {};

  /// Evaluates a download failure and schedules automatic retry if eligible.
  Future<bool> scheduleRetryIfEligible(DownloadProgress progress) async {
    if (progress.status != DownloadStatus.failed) return false;

    final failure = progress.failure;
    if (failure == null) return false;

    // Only retry transport or platform failures
    final isRecoverable =
        failure.code == DownloadFailureCode.transport ||
        failure.code == DownloadFailureCode.platformUnavailable;
    if (!isRecoverable) return false;

    final currentAttempts = _retryAttempts[progress.artifactId] ?? 0;
    if (currentAttempts >= maxRetryCount) return false;

    final nextAttempts = currentAttempts + 1;
    _retryAttempts[progress.artifactId] = nextAttempts;

    final delayIndex = (nextAttempts - 1).clamp(0, retryDelays.length - 1);
    final delay = retryDelays[delayIndex];

    unawaited(
      Future.delayed(delay, () async {
        await downloader.retry(progress.artifactId);
      }),
    );

    return true;
  }

  void resetAttempts(String artifactId) {
    _retryAttempts.remove(artifactId);
  }
}
