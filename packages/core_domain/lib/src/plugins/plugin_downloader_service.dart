/// Plugin Downloader Service
///
/// Abstract interface for downloading and verifying plugin bundles.
library;

import 'package:meta/meta.dart';
import 'plugin_manifest.dart';

/// Progress of a plugin download.
@immutable
class DownloadProgress {
  const DownloadProgress({
    required this.pluginId,
    required this.totalBytes,
    required this.downloadedBytes,
    required this.status,
    this.error,
  });

  /// The plugin being downloaded.
  final String pluginId;

  /// Total size in bytes.
  final int totalBytes;

  /// Bytes downloaded so far.
  final int downloadedBytes;

  /// Current download status.
  final DownloadStatus status;

  /// Error message if download failed.
  final String? error;

  /// Progress as a percentage (0.0 - 1.0).
  double get progress => totalBytes > 0 ? downloadedBytes / totalBytes : 0.0;

  /// Progress as a percentage (0 - 100).
  int get progressPercent => (progress * 100).round();

  /// Whether the download is complete.
  bool get isComplete => status == DownloadStatus.completed;

  /// Whether the download failed.
  bool get isFailed => status == DownloadStatus.failed;

  /// Whether the download is in progress.
  bool get isInProgress => status == DownloadStatus.downloading;

  /// Create a starting progress.
  factory DownloadProgress.starting(String pluginId) {
    return DownloadProgress(
      pluginId: pluginId,
      totalBytes: 0,
      downloadedBytes: 0,
      status: DownloadStatus.pending,
    );
  }

  /// Create a completed progress.
  factory DownloadProgress.completed(String pluginId, int totalBytes) {
    return DownloadProgress(
      pluginId: pluginId,
      totalBytes: totalBytes,
      downloadedBytes: totalBytes,
      status: DownloadStatus.completed,
    );
  }

  /// Create a failed progress.
  factory DownloadProgress.failed(String pluginId, String error) {
    return DownloadProgress(
      pluginId: pluginId,
      totalBytes: 0,
      downloadedBytes: 0,
      status: DownloadStatus.failed,
      error: error,
    );
  }
}

/// Status of a download operation.
enum DownloadStatus {
  /// Download is pending.
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

  /// Verifying integrity.
  verifying,
}

/// Result of integrity verification.
@immutable
class VerificationResult {
  const VerificationResult({
    required this.pluginId,
    required this.isValid,
    this.errorMessage,
  });

  final String pluginId;
  final bool isValid;
  final String? errorMessage;

  factory VerificationResult.valid(String pluginId) {
    return VerificationResult(pluginId: pluginId, isValid: true);
  }

  factory VerificationResult.invalid(String pluginId, String error) {
    return VerificationResult(
      pluginId: pluginId,
      isValid: false,
      errorMessage: error,
    );
  }
}

/// Service for downloading and verifying plugin bundles.
abstract class PluginDownloaderService {
  /// Download a plugin.
  ///
  /// Returns a stream of [DownloadProgress] updates.
  Stream<DownloadProgress> downloadPlugin(PluginManifest manifest);

  /// Pause a download.
  Future<void> pauseDownload(String pluginId);

  /// Resume a paused download.
  Future<void> resumeDownload(String pluginId);

  /// Cancel a download.
  Future<void> cancelDownload(String pluginId);

  /// Verify the integrity of a downloaded plugin.
  ///
  /// Checks the SHA-256 checksum and optional signature.
  Future<VerificationResult> verifyIntegrity(
    String pluginId,
    PluginChecksums expectedChecksums,
  );

  /// Get the current download progress for a plugin.
  DownloadProgress? getDownloadProgress(String pluginId);

  /// Check if a download is in progress for a plugin.
  bool isDownloading(String pluginId);

  /// Get all active downloads.
  List<DownloadProgress> getActiveDownloads();
}
