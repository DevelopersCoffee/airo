// ignore_for_file: one_member_abstracts
import 'package:platform_downloads/src/manifest/download_manifest.dart';

abstract interface class DownloadMirror {
  String resolveUrl(DownloadArtifactDescriptor descriptor);
}
