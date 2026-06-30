enum ValidationStatus {
  success,
  warnings,
  failed,
}

class ValidationReport {

  const ValidationReport({
    required this.status,
    this.warnings = const [],
    this.errors = const [],
    this.extractedMetadata = const {},
    this.detectedArchitecture,
    this.quantization,
    this.contextSize,
    this.checksum,
    this.runtimeRecommendations = const [],
  });
  final ValidationStatus status;
  final List<String> warnings;
  final List<String> errors;
  final Map<String, dynamic> extractedMetadata;
  final String? detectedArchitecture;
  final String? quantization;
  final int? contextSize;
  final String? checksum;
  final List<String> runtimeRecommendations;

  bool get isSafe => status != ValidationStatus.failed;
}
