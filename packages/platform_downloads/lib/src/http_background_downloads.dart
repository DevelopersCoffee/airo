import 'dart:async';
import 'dart:io';

import 'background_downloads.dart';
import 'download_models.dart';

/// Progressive downloads for desktop hosts without a native WorkManager /
/// URLSession plugin (`platform_downloads` is Android/iOS only today).
class HttpBackgroundDownloads implements BackgroundDownloads {
  HttpBackgroundDownloads({HttpClient Function()? clientFactory})
    : _clientFactory = clientFactory ?? HttpClient.new;

  final HttpClient Function() _clientFactory;
  final StreamController<DownloadProgress> _events =
      StreamController<DownloadProgress>.broadcast();
  final Map<String, _HttpDownloadJob> _jobs = {};

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
      entries: [
        for (final job in _jobs.values) job.snapshot(),
      ],
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
      final request = await client.getUrl(job.request.source);
      request.followRedirects = true;
      request.maxRedirects = 8;
      final response = await request.close();
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
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw HttpException('HTTP ${response.statusCode}');
      }

      final contentLength = response.contentLength;
      if (contentLength > 0) {
        job.totalBytes = contentLength;
      } else if (job.request.expectedBytes != null) {
        job.totalBytes = job.request.expectedBytes!;
      }

      final sink = partial.openWrite();
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

      if (job.cancelRequested) return;

      final expected = job.request.expectedBytes;
      if (expected != null && partial.lengthSync() != expected) {
        partial.deleteSync();
        job.status = DownloadStatus.failed;
        job.failure = const DownloadFailure(
          code: DownloadFailureCode.integrityMismatch,
          message: 'Downloaded size did not match the expected byte count.',
        );
        _emit(job.snapshot());
        return;
      }

      if (destination.existsSync()) {
        destination.deleteSync();
      }
      partial.renameSync(destination.path);

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

  void _emit(DownloadProgress progress) {
    if (!_events.isClosed) {
      _events.add(progress);
    }
  }
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
    resumeSupported: false,
  );
}
