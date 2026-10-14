import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

import 'background_downloads.dart';
import 'download_models.dart';
import 'processors/streaming_checksum.dart';

/// Progressive downloads for desktop hosts without a native WorkManager /
/// URLSession plugin (`platform_downloads` is Android/iOS only today).
class HttpBackgroundDownloads implements BackgroundDownloads {
  HttpBackgroundDownloads({
    HttpClient Function()? clientFactory,
    this._onBeforeCommitPartial,
  }) : _clientFactory = clientFactory ?? HttpClient.new;

  final HttpClient Function() _clientFactory;
  final Future<void> Function(File partial, File destination)?
  _onBeforeCommitPartial;
  final StreamController<DownloadProgress> _events =
      StreamController<DownloadProgress>.broadcast();
  final Map<String, _HttpDownloadJob> _jobs = {};

  @visibleForTesting
  Future<void> Function(File partial, File destination)?
  get onBeforeCommitPartial => _onBeforeCommitPartial;

  @override
  Stream<DownloadProgress> get events => _events.stream;

  @override
  Future<void> enqueue(DownloadArtifactRequest request) async {
    final existing = _jobs[request.artifactId];
    if (existing != null &&
        existing.status != DownloadStatus.failed &&
        existing.status != DownloadStatus.cancelled) {
      return;
    }

    final job = _HttpDownloadJob(request: request);
    _jobs[request.artifactId] = job;
    _emit(job.queued());
    unawaited(_run(job));
  }

  @override
  Future<void> pause(String artifactId) async {
    final job = _jobs[artifactId];
    if (job == null) return;
    job.cancelRequested = true;
    job.client?.close(force: true);
    job.status = DownloadStatus.paused;
    _emit(job.snapshot());
  }

  @override
  Future<void> resume(String artifactId) async {
    final job = _jobs[artifactId];
    if (job == null) return;
    job.cancelRequested = false;
    unawaited(_run(job));
  }

  @override
  Future<void> retry(String artifactId) async {
    final job = _jobs[artifactId];
    if (job == null) return;
    job.cancelRequested = false;
    job.downloadedBytes = 0;
    job.retryCount += 1;
    job.status = DownloadStatus.queued;
    _emit(job.snapshot());
    unawaited(_run(job));
  }

  @override
  Future<void> cancel(String artifactId) async {
    final job = _jobs[artifactId];
    if (job == null) return;
    job.cancelRequested = true;
    job.client?.close(force: true);
    job.status = DownloadStatus.cancelled;
    _emit(
      DownloadProgress(
        artifactId: artifactId,
        status: DownloadStatus.cancelled,
        downloadedBytes: job.downloadedBytes,
        totalBytes: job.totalBytes,
        retryCount: job.retryCount,
        failure: const DownloadFailure(code: DownloadFailureCode.cancelled),
      ),
    );
    _jobs.remove(artifactId);
  }

  @override
  Future<DownloadQueueSnapshot> getQueue() async {
    return DownloadQueueSnapshot(
      entries: [for (final job in _jobs.values) job.snapshot()],
    );
  }

  @override
  Future<int?> getAvailableBytes() async => null;

  Future<void> _run(_HttpDownloadJob job) async {
    if (job.cancelRequested) return;

    final partial = File('${job.request.destinationPath}.partial');
    final destination = File(job.request.destinationPath);
    final parent = destination.parent;
    if (!parent.existsSync()) {
      parent.createSync(recursive: true);
    }

    job.status = DownloadStatus.downloading;
    _emit(job.snapshot());

    final client = _clientFactory();
    client.userAgent = 'Airo/1.0 (platform_downloads; dart)';
    job.client = client;
    final startedAt = DateTime.now();

    try {
      await _downloadBody(job, client, partial, startedAt);

      if (job.cancelRequested) return;

      final expected = job.request.expectedBytes;
      if (expected != null && partial.lengthSync() != expected) {
        job.status = DownloadStatus.failed;
        job.failure = const DownloadFailure(
          code: DownloadFailureCode.integrityMismatch,
          message: 'Downloaded size did not match the expected byte count.',
        );
        _emit(job.snapshot());
        return;
      }

      job.status = DownloadStatus.verifying;
      _emit(job.snapshot());

      final expectedSha256 = job.request.expectedSha256;
      if (expectedSha256 != null &&
          !await fileMatchesSha256Hex(partial, expectedSha256)) {
        job.status = DownloadStatus.failed;
        job.failure = const DownloadFailure(
          code: DownloadFailureCode.integrityMismatch,
          message: 'SHA-256 checksum did not match expected value.',
        );
        _emit(job.snapshot());
        return;
      }

      final hook = _onBeforeCommitPartial;
      if (hook != null) {
        await hook(partial, destination);
      }

      await _commitPartialFile(partial, destination);

      job.status = DownloadStatus.completed;
      job.downloadedBytes = destination.lengthSync();
      job.totalBytes = job.downloadedBytes;
      _emit(job.snapshot());
      _jobs.remove(job.request.artifactId);
    } on Object catch (error) {
      if (job.cancelRequested) return;
      job.status = DownloadStatus.failed;
      job.failure = DownloadFailure(
        code: DownloadFailureCode.transport,
        message: '$error',
      );
      _emit(job.snapshot());
    } finally {
      client.close(force: true);
      job.client = null;
    }
  }

  Future<void> _downloadBody(
    _HttpDownloadJob job,
    HttpClient client,
    File partial,
    DateTime startedAt,
  ) async {
    while (true) {
      if (job.cancelRequested) return;

      final resumeOffset = partial.existsSync() ? partial.lengthSync() : 0;
      job.downloadedBytes = resumeOffset;

      final outgoing = await client.getUrl(job.request.source);
      outgoing.followRedirects = true;
      outgoing.maxRedirects = 8;
      for (final entry in job.request.headers.entries) {
        outgoing.headers.set(entry.key, entry.value);
      }
      if (resumeOffset > 0) {
        outgoing.headers.set(HttpHeaders.rangeHeader, 'bytes=$resumeOffset-');
      }

      final response = await outgoing.close();
      if (response.statusCode == 401 || response.statusCode == 403) {
        final host = job.request.source.host;
        final gatedHf = host.contains('huggingface.co');
        throw HttpException(
          gatedHf
              ? 'HTTP ${response.statusCode}: this Hugging Face file is gated. '
                    'Use a public GGUF (Unsloth) or a token with license access.'
              : 'HTTP ${response.statusCode}',
        );
      }

      final parsedRange = _parseContentRange(
        response.headers.value(HttpHeaders.contentRangeHeader),
      );
      var append =
          resumeOffset > 0 &&
          response.statusCode == HttpStatus.partialContent &&
          parsedRange != null &&
          parsedRange.start == resumeOffset &&
          _contentRangeTotalIsConsistent(
            parsedRange,
            job.request.expectedBytes,
          );

      if (resumeOffset > 0 && !append) {
        if (response.statusCode == HttpStatus.ok) {
          if (partial.existsSync()) {
            partial.deleteSync();
          }
          job.downloadedBytes = 0;
        } else {
          await _drainResponse(response);
          if (partial.existsSync()) {
            partial.deleteSync();
          }
          job.downloadedBytes = 0;
          continue;
        }
      }

      if (response.statusCode != HttpStatus.ok &&
          response.statusCode != HttpStatus.partialContent) {
        throw HttpException('HTTP ${response.statusCode}');
      }

      _applyTotalBytes(job, response, parsedRange: parsedRange, append: append);

      final sink = partial.openWrite(
        mode: append ? FileMode.append : FileMode.write,
      );
      try {
        await for (final chunk in response) {
          if (job.cancelRequested) {
            await sink.close();
            return;
          }
          sink.add(chunk);
          job.downloadedBytes += chunk.length;
          final elapsed = DateTime.now().difference(startedAt).inMilliseconds;
          job.speedBytesPerSecond = elapsed <= 0
              ? 0
              : job.downloadedBytes * 1000 / elapsed;
          _emit(job.snapshot());
        }
      } finally {
        await sink.close();
      }
      return;
    }
  }

  void _applyTotalBytes(
    _HttpDownloadJob job,
    HttpClientResponse response, {
    required _ParsedContentRange? parsedRange,
    required bool append,
  }) {
    if (parsedRange?.total != null) {
      job.totalBytes = parsedRange!.total!;
      return;
    }
    final contentLength = response.contentLength;
    if (contentLength > 0) {
      job.totalBytes = append
          ? job.downloadedBytes + contentLength
          : contentLength;
    } else if (job.request.expectedBytes != null) {
      job.totalBytes = job.request.expectedBytes!;
    }
  }

  Future<void> _commitPartialFile(File partial, File destination) async {
    if (Platform.isWindows && await destination.exists()) {
      final backup = File('${destination.path}.old');
      if (await backup.exists()) {
        await backup.delete();
      }
      await destination.rename(backup.path);
      try {
        await partial.rename(destination.path);
        if (await backup.exists()) {
          await backup.delete();
        }
      } on Object {
        if (await backup.exists() && !await destination.exists()) {
          await backup.rename(destination.path);
        }
        rethrow;
      }
      return;
    }
    await partial.rename(destination.path);
  }

  Future<void> _drainResponse(HttpClientResponse response) async {
    await for (final _ in response) {}
  }

  void _emit(DownloadProgress progress) {
    if (!_events.isClosed) {
      _events.add(progress);
    }
  }
}

class _ParsedContentRange {
  const _ParsedContentRange({
    required this.start,
    required this.end,
    this.total,
  });

  final int start;
  final int end;
  final int? total;
}

_ParsedContentRange? _parseContentRange(String? header) {
  if (header == null) return null;
  final match = RegExp(
    r'^bytes (\d+)-(\d+)/(\d+|\*)$',
  ).firstMatch(header.trim());
  if (match == null) return null;
  final totalGroup = match.group(3);
  return _ParsedContentRange(
    start: int.parse(match.group(1)!),
    end: int.parse(match.group(2)!),
    total: totalGroup == '*' ? null : int.parse(totalGroup!),
  );
}

bool _contentRangeTotalIsConsistent(
  _ParsedContentRange range,
  int? expectedBytes,
) {
  if (expectedBytes == null || range.total == null) {
    return true;
  }
  return range.total == expectedBytes;
}

class _HttpDownloadJob {
  _HttpDownloadJob({required this.request})
    : totalBytes = request.expectedBytes ?? 0;

  final DownloadArtifactRequest request;
  DownloadStatus status = DownloadStatus.queued;
  int downloadedBytes = 0;
  int totalBytes;
  double speedBytesPerSecond = 0;
  int retryCount = 0;
  DownloadFailure? failure;
  bool cancelRequested = false;
  HttpClient? client;

  DownloadProgress queued() => DownloadProgress(
    artifactId: request.artifactId,
    status: DownloadStatus.queued,
    downloadedBytes: 0,
    totalBytes: totalBytes,
    retryCount: retryCount,
    queuePosition: 0,
  );

  DownloadProgress snapshot() => DownloadProgress(
    artifactId: request.artifactId,
    status: status,
    downloadedBytes: downloadedBytes,
    totalBytes: totalBytes,
    speedBytesPerSecond: speedBytesPerSecond,
    retryCount: retryCount,
    failure: failure,
    resumeSupported: true,
  );
}
