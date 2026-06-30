// ignore_for_file: one_member_abstracts
import 'package:platform_core/platform_core.dart';
import 'package:platform_downloads/src/manifest/download_manifest.dart';

abstract interface class DownloadVerifier {
  Future<Result<bool>> verify(String filePath, DownloadArtifactDescriptor descriptor);
}
