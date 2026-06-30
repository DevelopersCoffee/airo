import 'package:platform_downloads/platform_downloads.dart';
import 'package:platform_validation/src/reports/validation_report.dart';

class InstalledArtifact {

  const InstalledArtifact({
    required this.installationId,
    required this.artifactId,
    required this.descriptor,
    required this.installLocation, required this.validationReport, required this.installedVersion, this.validatedMetadata = const {},
  });
  final String installationId;
  final String artifactId;
  final DownloadArtifactDescriptor descriptor;
  final Map<String, dynamic> validatedMetadata;
  final String installLocation;
  final ValidationReport validationReport;
  final String installedVersion;
}
