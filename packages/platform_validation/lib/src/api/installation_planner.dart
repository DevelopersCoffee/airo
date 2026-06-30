// ignore_for_file: one_member_abstracts
import 'package:platform_core/platform_core.dart';
import 'package:platform_downloads/platform_downloads.dart';
import 'package:platform_validation/src/models/installed_artifact.dart';

abstract interface class InstallationPlanner {
  Future<Result<InstalledArtifact>> planAndInstall(
    String installationId,
    List<DownloadedArtifact> artifacts,
  );
}
