import 'package:meta/meta.dart';

/// Framework-minted provenance handle referenced by extracted facts.
@immutable
class GraphProvenanceRef {
  const GraphProvenanceRef({
    required this.sourceMessageRevision,
    required this.manifestDigest,
    required this.adapterDigest,
    required this.extractionContractVersion,
  });

  final String sourceMessageRevision;
  final String manifestDigest;
  final String adapterDigest;
  final String extractionContractVersion;

  factory GraphProvenanceRef.fromJson(Map<String, dynamic> json) =>
      GraphProvenanceRef(
        sourceMessageRevision: json['source_message_revision'] as String,
        manifestDigest: json['manifest_digest'] as String,
        adapterDigest: json['adapter_digest'] as String,
        extractionContractVersion:
            json['extraction_contract_version'] as String,
      );

  Map<String, dynamic> toJson() => {
    'source_message_revision': sourceMessageRevision,
    'manifest_digest': manifestDigest,
    'adapter_digest': adapterDigest,
    'extraction_contract_version': extractionContractVersion,
  };

  @override
  bool operator ==(Object other) =>
      other is GraphProvenanceRef &&
      other.sourceMessageRevision == sourceMessageRevision &&
      other.manifestDigest == manifestDigest &&
      other.adapterDigest == adapterDigest &&
      other.extractionContractVersion == extractionContractVersion;

  @override
  int get hashCode => Object.hash(
    sourceMessageRevision,
    manifestDigest,
    adapterDigest,
    extractionContractVersion,
  );
}
