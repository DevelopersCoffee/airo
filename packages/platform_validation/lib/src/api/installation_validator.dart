// ignore_for_file: one_member_abstracts
import 'package:platform_core/platform_core.dart';
import 'package:platform_validation/src/models/installed_artifact.dart';
import 'package:platform_validation/src/reports/validation_report.dart';

abstract interface class InstallationValidator {
  Future<Result<ValidationReport>> validateInstallation(InstalledArtifact installedArtifact);
}
