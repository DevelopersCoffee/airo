import 'package:platform_downloads/src/manifest/download_manifest.dart';

abstract interface class DownloadService {
  Future<String> enqueueDownload(DownloadManifest manifest);
  Future<void> pauseDownload(String downloadId);
  Future<void> resumeDownload(String downloadId);
  Future<void> cancelDownload(String downloadId);
}
