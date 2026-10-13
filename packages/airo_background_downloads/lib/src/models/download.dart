import 'package:flutter/foundation.dart';

import 'request.dart';

/// Detailed transfer state machine status.
enum AiroDownloadStatus {
  queued,
  waitingForNetwork,
  waitingForPower,
  preparing,
  downloading,
  paused,
  verifying,
  processing,
  completed,
  failed,
  cancelled,
}

/// Classified failure reasons for structured error handling.
enum AiroFailureReason {
  network,
  timeout,
  server,
  client,
  cancelled,
  storage,
  checksum,
  permission,
  unsupported,
  unknown,
}

/// Dynamic storage requirement matrix.
@immutable
class AiroStorageRequirement {
  const AiroStorageRequirement({
    required this.downloadBytes,
    this.temporaryBytes = 0,
    this.processingBytes = 0,
    this.safetyBytes = 50 * 1024 * 1024,
  });

  final int downloadBytes;
  final int temporaryBytes;
  final int processingBytes;
  final int safetyBytes;

  int get totalRequiredBytes =>
      downloadBytes + temporaryBytes + processingBytes + safetyBytes;
}

/// Active or completed transfer record snapshot.
@immutable
class AiroDownload {
  const AiroDownload({
    required this.request,
    required this.status,
    required this.downloadedBytes,
    required this.totalBytes,
    this.speedBytesPerSecond = 0,
    this.retryCount = 0,
    this.failureReason,
    this.failureMessage,
  });

  final AiroDownloadRequest request;
  final AiroDownloadStatus status;
  final int downloadedBytes;
  final int totalBytes;
  final double speedBytesPerSecond;
  final int retryCount;
  final AiroFailureReason? failureReason;
  final String? failureMessage;

  String get id => request.id;

  double get fraction =>
      totalBytes <= 0 ? 0.0 : (downloadedBytes / totalBytes).clamp(0.0, 1.0);

  bool get isTerminal =>
      status == AiroDownloadStatus.completed ||
      status == AiroDownloadStatus.cancelled ||
      status == AiroDownloadStatus.failed;

  Map<String, Object?> toMap() => {
    'id': id,
    'request': request.toMap(),
    'status': status.name,
    'downloadedBytes': downloadedBytes,
    'totalBytes': totalBytes,
    'speedBytesPerSecond': speedBytesPerSecond,
    'retryCount': retryCount,
    if (failureReason != null) 'failureReason': failureReason!.name,
    if (failureMessage != null) 'failureMessage': failureMessage,
  };

  factory AiroDownload.fromMap(Map<Object?, Object?> map) {
    final statusName = map['status'] as String? ?? 'failed';
    final status = AiroDownloadStatus.values.firstWhere(
      (e) => e.name == statusName,
      orElse: () => AiroDownloadStatus.failed,
    );

    final failureName = map['failureReason'] as String?;
    final failureReason = failureName == null
        ? null
        : AiroFailureReason.values.firstWhere(
            (e) => e.name == failureName,
            orElse: () => AiroFailureReason.unknown,
          );

    return AiroDownload(
      request: AiroDownloadRequest.fromMap(
        (map['request'] as Map? ?? {}).cast<Object?, Object?>(),
      ),
      status: status,
      downloadedBytes: (map['downloadedBytes'] as num?)?.toInt() ?? 0,
      totalBytes: (map['totalBytes'] as num?)?.toInt() ?? 0,
      speedBytesPerSecond:
          (map['speedBytesPerSecond'] as num?)?.toDouble() ?? 0,
      retryCount: (map['retryCount'] as num?)?.toInt() ?? 0,
      failureReason: failureReason,
      failureMessage: map['failureMessage'] as String?,
    );
  }
}
