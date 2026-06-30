// ignore_for_file: one_member_abstracts
import 'package:platform_core/platform_core.dart';
import 'package:platform_downloads/platform_downloads.dart';
import 'package:platform_validation/src/reports/validation_report.dart';

abstract interface class ArtifactValidator {
  Future<Result<ValidationReport>> validateArtifact(DownloadedArtifact artifact);
}
