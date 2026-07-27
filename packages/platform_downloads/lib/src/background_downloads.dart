import 'download_models.dart';

/// Stable application-facing contract for progressive background downloads.
abstract interface class BackgroundDownloads {
  Stream<DownloadProgress> get events;

  Future<void> enqueue(DownloadArtifactRequest request);

  Future<void> pause(String artifactId);

  Future<void> resume(String artifactId);

  Future<void> retry(String artifactId);

  Future<void> cancel(String artifactId);

  Future<DownloadQueueSnapshot> getQueue();
}
