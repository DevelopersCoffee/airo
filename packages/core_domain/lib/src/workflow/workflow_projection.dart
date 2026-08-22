import 'package:meta/meta.dart';

import '../addons/addon_id.dart';
import '../addons/addon_identity.dart';
import 'offer_decision.dart';

@immutable
class WorkflowProjection {
  const WorkflowProjection({
    required this.identity,
    required this.subjectNodeId,
    required this.destinationKind,
    required this.templateId,
    required this.templateVersion,
    required this.title,
    required this.factsByFieldId,
    required this.identityKey,
    required this.offer,
    this.displayFacts = const {},
  });

  final AddonIdentity identity;
  final String subjectNodeId;
  final String destinationKind;
  final String templateId;
  final String templateVersion;
  final String title;
  final Map<String, String> factsByFieldId;
  final Map<String, String> displayFacts;
  final String identityKey;
  final OfferDecision offer;

  bool get isOfferable => offer.isOfferable;

  factory WorkflowProjection.fromJson(Map<String, dynamic> json) =>
      WorkflowProjection(
        identity: AddonIdentity(
          id: AddonId(json['addon_id'] as String),
          version: json['addon_version'] as String,
          manifestDigest: json['manifest_digest'] as String? ?? '',
          adapterDigest: json['adapter_digest'] as String? ?? '',
        ),
        subjectNodeId: json['subject_node_id'] as String,
        destinationKind: json['destination_kind'] as String,
        templateId: json['template_id'] as String,
        templateVersion: json['template_version'] as String? ?? '1',
        title: json['title'] as String,
        factsByFieldId: ((json['facts_by_field_id'] as Map?) ?? const {}).map(
          (key, value) => MapEntry(key.toString(), value.toString()),
        ),
        displayFacts: ((json['display_facts'] as Map?) ?? const {}).map(
          (key, value) => MapEntry(key.toString(), value.toString()),
        ),
        identityKey: json['identity_key'] as String,
        offer: OfferDecision.fromJson(json['offer'] as Map<String, dynamic>),
      );

  Map<String, dynamic> toJson() => {
    'addon_id': identity.id.value,
    'addon_version': identity.version,
    if (identity.manifestDigest.isNotEmpty)
      'manifest_digest': identity.manifestDigest,
    if (identity.adapterDigest.isNotEmpty)
      'adapter_digest': identity.adapterDigest,
    'subject_node_id': subjectNodeId,
    'destination_kind': destinationKind,
    'template_id': templateId,
    'template_version': templateVersion,
    'title': title,
    'facts_by_field_id': factsByFieldId,
    if (displayFacts.isNotEmpty) 'display_facts': displayFacts,
    'identity_key': identityKey,
    'offer': offer.toJson(),
  };
}
