import 'package:meta/meta.dart';

/// Durable evidence describing the catalog artifact installed for a model.
///
/// A missing receipt means the installed artifact predates receipt tracking;
/// callers must report its update state as unknown rather than guessing.
@immutable
class ModelInstallReceipt {
  const ModelInstallReceipt({
    required this.modelId,
    required this.catalogFingerprint,
    required this.installedAt,
    this.version,
    this.sha256,
  });

  factory ModelInstallReceipt.fromJson(Map<String, Object?> json) {
    final modelId = json['modelId'];
    final fingerprint = json['catalogFingerprint'];
    final installedAt = json['installedAt'];
    if (modelId is! String ||
        modelId.trim().isEmpty ||
        fingerprint is! String ||
        fingerprint.trim().isEmpty ||
        installedAt is! String) {
      throw const FormatException('Invalid model install receipt');
    }
    final parsedInstalledAt = DateTime.tryParse(installedAt);
    if (parsedInstalledAt == null) {
      throw const FormatException('Invalid model install timestamp');
    }
    return ModelInstallReceipt(
      modelId: modelId,
      catalogFingerprint: fingerprint,
      installedAt: parsedInstalledAt.toUtc(),
      version: json['version'] as String?,
      sha256: json['sha256'] as String?,
    );
  }

  final String modelId;
  final String catalogFingerprint;
  final DateTime installedAt;
  final String? version;
  final String? sha256;

  Map<String, Object?> toJson() => <String, Object?>{
    'schemaVersion': 1,
    'modelId': modelId,
    'catalogFingerprint': catalogFingerprint,
    'installedAt': installedAt.toUtc().toIso8601String(),
    if (version != null) 'version': version,
    if (sha256 != null) 'sha256': sha256,
  };
}
