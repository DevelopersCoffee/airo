import 'package:flutter/foundation.dart';

const int backgroundDownloadContractVersion = 1;

@immutable
class DownloadArtifactRequest {
  DownloadArtifactRequest({
    required String artifactId,
    required this.source,
    required String destinationPath,
    this.expectedBytes,
    String? expectedSha256,
    String? displayName,
  }) : artifactId = _validatedArtifactId(artifactId),
       destinationPath = _requiredText(destinationPath, 'destinationPath'),
       expectedSha256 = _validatedSha256(expectedSha256),
       displayName = _optionalText(displayName, 'displayName') {
    if (source.scheme.toLowerCase() != 'https' || source.host.isEmpty) {
      throw ArgumentError.value(source, 'source', 'must be an HTTPS URI');
    }
    if (source.userInfo.isNotEmpty) {
      throw ArgumentError.value(source, 'source', 'must not embed credentials');
    }
    final byteCount = expectedBytes;
    if (byteCount != null && byteCount <= 0) {
      throw ArgumentError.value(byteCount, 'expectedBytes', 'must be positive');
    }
  }

  final String artifactId;
  final Uri source;
  final String destinationPath;
  final int? expectedBytes;
  final String? expectedSha256;
  final String? displayName;

  Map<String, Object?> toPlatformMap() => <String, Object?>{
    'contractVersion': backgroundDownloadContractVersion,
    'artifactId': artifactId,
    'source': source.toString(),
    'destinationPath': destinationPath,
    if (expectedBytes != null) 'expectedBytes': expectedBytes,
    if (expectedSha256 != null) 'expectedSha256': expectedSha256,
    if (displayName != null) 'displayName': displayName,
  };

  static String _requiredText(String value, String name) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError.value(value, name, 'must not be empty');
    }
    return trimmed;
  }

  static String? _optionalText(String? value, String name) {
    if (value == null) return null;
    return _requiredText(value, name);
  }

  static String _validatedArtifactId(String value) {
    final normalized = _requiredText(value, 'artifactId');
    if (!RegExp(r'^[A-Za-z0-9][A-Za-z0-9._-]{0,127}$').hasMatch(normalized)) {
      throw ArgumentError.value(
        value,
        'artifactId',
        'must be a safe 1-128 character identifier',
      );
    }
    return normalized;
  }

  static String? _validatedSha256(String? value) {
    if (value == null) return null;
    final normalized = value.trim().toLowerCase();
    if (!RegExp(r'^[a-f0-9]{64}$').hasMatch(normalized)) {
      throw ArgumentError.value(
        value,
        'expectedSha256',
        'must contain 64 hexadecimal characters',
      );
    }
    return normalized;
  }
}

enum DownloadStatus {
  queued,
  downloading,
  paused,
  verifying,
  completed,
  failed,
  cancelled,
}

enum DownloadFailureCode {
  invalidRequest,
  insufficientStorage,
  transport,
  resumeNotSupported,
  integrityMismatch,
  platformUnavailable,
  cleanupFailed,
  cancelled,
}

@immutable
class DownloadFailure {
  const DownloadFailure({required this.code, this.message});

  final DownloadFailureCode code;
  final String? message;
}

@immutable
class DownloadProgress {
  const DownloadProgress({
    required this.artifactId,
    required this.status,
    required this.downloadedBytes,
    required this.totalBytes,
    this.speedBytesPerSecond = 0,
    this.retryCount = 0,
    this.queuePosition,
    this.failure,
    this.resumeSupported = false,
  });

  factory DownloadProgress.fromMap(Map<Object?, Object?> map) {
    final rawStatus = _string(map, 'status') ?? '';
    final parsedStatus = _statusFromWire(rawStatus);
    final unknownStatus = parsedStatus == null;
    final status = parsedStatus ?? DownloadStatus.failed;
    final rawFailureCode = _string(map, 'failureCode');
    final parsedFailure = rawFailureCode == null
        ? null
        : _failureCodeFromWire(rawFailureCode);
    final failure = unknownStatus
        ? const DownloadFailure(
            code: DownloadFailureCode.platformUnavailable,
            message: 'Unsupported platform download status',
          )
        : status == DownloadStatus.failed ||
              status == DownloadStatus.cancelled ||
              rawFailureCode != null
        ? DownloadFailure(
            code:
                parsedFailure ??
                (status == DownloadStatus.cancelled
                    ? DownloadFailureCode.cancelled
                    : DownloadFailureCode.platformUnavailable),
            message: _string(map, 'failureMessage'),
          )
        : null;

    return DownloadProgress(
      artifactId: _requiredWireText(map, 'artifactId'),
      status: status,
      downloadedBytes: _nonNegativeInt(map, 'downloadedBytes'),
      totalBytes: _nonNegativeInt(map, 'totalBytes'),
      speedBytesPerSecond: _nonNegativeDouble(map, 'speedBytesPerSecond'),
      retryCount: _nonNegativeInt(map, 'retryCount'),
      queuePosition: _nullableNonNegativeInt(map, 'queuePosition'),
      failure: failure,
      resumeSupported: map['canResume'] == true,
    );
  }

  final String artifactId;
  final DownloadStatus status;
  final int downloadedBytes;
  final int totalBytes;
  final double speedBytesPerSecond;
  final int retryCount;
  final int? queuePosition;
  final DownloadFailure? failure;
  final bool resumeSupported;

  double get fraction =>
      totalBytes <= 0 ? 0 : (downloadedBytes / totalBytes).clamp(0.0, 1.0);

  bool get canPause => status == DownloadStatus.downloading;

  bool get canResume =>
      status == DownloadStatus.paused ||
      (status == DownloadStatus.failed && resumeSupported);

  bool get canRetry => status == DownloadStatus.failed;

  bool get canCancel =>
      status != DownloadStatus.completed && status != DownloadStatus.cancelled;

  bool get isTerminal =>
      status == DownloadStatus.completed ||
      status == DownloadStatus.cancelled ||
      (status == DownloadStatus.failed && !canRetry && !canResume);
}

@immutable
class DownloadQueueSnapshot {
  const DownloadQueueSnapshot({required this.entries});

  factory DownloadQueueSnapshot.fromMap(Map<Object?, Object?> map) {
    final rawEntries = map['entries'];
    if (rawEntries is! List) {
      return const DownloadQueueSnapshot(entries: <DownloadProgress>[]);
    }
    return DownloadQueueSnapshot(
      entries: List<DownloadProgress>.unmodifiable(
        rawEntries.whereType<Map>().map(
          (entry) => DownloadProgress.fromMap(entry.cast<Object?, Object?>()),
        ),
      ),
    );
  }

  final List<DownloadProgress> entries;
}

DownloadStatus? _statusFromWire(String value) {
  return switch (value) {
    'queued' || 'pending' => DownloadStatus.queued,
    'downloading' => DownloadStatus.downloading,
    'paused' => DownloadStatus.paused,
    'verifying' => DownloadStatus.verifying,
    'completed' => DownloadStatus.completed,
    'failed' => DownloadStatus.failed,
    'cancelled' => DownloadStatus.cancelled,
    _ => null,
  };
}

DownloadFailureCode? _failureCodeFromWire(String value) {
  return switch (value) {
    'invalid_request' => DownloadFailureCode.invalidRequest,
    'insufficient_storage' => DownloadFailureCode.insufficientStorage,
    'transport' => DownloadFailureCode.transport,
    'resume_not_supported' => DownloadFailureCode.resumeNotSupported,
    'integrity_mismatch' => DownloadFailureCode.integrityMismatch,
    'platform_unavailable' => DownloadFailureCode.platformUnavailable,
    'cleanup_failed' => DownloadFailureCode.cleanupFailed,
    'cancelled' => DownloadFailureCode.cancelled,
    _ => null,
  };
}

String _requiredWireText(Map<Object?, Object?> map, String key) {
  final value = _string(map, key)?.trim();
  if (value == null || value.isEmpty) {
    throw const FormatException('Missing download artifact identifier');
  }
  return value;
}

String? _string(Map<Object?, Object?> map, String key) {
  final value = map[key];
  return value is String ? value : null;
}

int _nonNegativeInt(Map<Object?, Object?> map, String key) {
  return _nullableNonNegativeInt(map, key) ?? 0;
}

int? _nullableNonNegativeInt(Map<Object?, Object?> map, String key) {
  final value = map[key];
  if (value is! num) return null;
  return value.toInt().clamp(0, 0x7fffffffffffffff);
}

double _nonNegativeDouble(Map<Object?, Object?> map, String key) {
  final value = map[key];
  if (value is! num || !value.isFinite || value < 0) return 0;
  return value.toDouble();
}
