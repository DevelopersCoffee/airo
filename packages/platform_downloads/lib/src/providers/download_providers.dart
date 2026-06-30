import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:platform_downloads/src/manifest/download_manifest.dart';
import '../api/download_service.dart';

class _MockDownloadService implements DownloadService {
  @override
  Future<String> enqueueDownload(DownloadManifest manifest) async => 'mock-id';
  @override
  Future<void> pauseDownload(String id) async {}
  @override
  Future<void> resumeDownload(String id) async {}
  @override
  Future<void> cancelDownload(String id) async {}
}

final downloadServiceProvider = Provider<DownloadService>((ref) {
  return _MockDownloadService();
});
