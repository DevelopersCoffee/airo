import 'package:meta/meta.dart';

import '../addons/addon_id.dart';
import '../addons/addon_identity.dart';

@immutable
class PendingAssessment {
  const PendingAssessment({
    required this.identity,
    required this.subjectNodeId,
    required this.storedFacts,
    required this.missingRequired,
    required this.missingOptional,
    this.crossLinks = const [],
    this.summary = '',
  });

  final AddonIdentity identity;
  final String subjectNodeId;
  final Map<String, String> storedFacts;
  final List<String> missingRequired;
  final List<String> missingOptional;
  final List<String> crossLinks;
  final String summary;

  factory PendingAssessment.fromJson(Map<String, dynamic> json) =>
      PendingAssessment(
        identity: AddonIdentity(
          id: AddonId(json['addon_id'] as String),
          version: json['addon_version'] as String,
        ),
        subjectNodeId: json['subject_node_id'] as String,
        storedFacts: ((json['stored_facts'] as Map?) ?? const {}).map(
          (key, value) => MapEntry(key.toString(), value.toString()),
        ),
        missingRequired: ((json['missing_required'] as List?) ?? const [])
            .map((item) => item.toString())
            .toList(growable: false),
        missingOptional: ((json['missing_optional'] as List?) ?? const [])
            .map((item) => item.toString())
            .toList(growable: false),
        crossLinks: ((json['cross_links'] as List?) ?? const [])
            .map((item) => item.toString())
            .toList(growable: false),
        summary: json['summary'] as String? ?? '',
      );

  Map<String, dynamic> toJson() => {
    'addon_id': identity.id.value,
    'addon_version': identity.version,
    'subject_node_id': subjectNodeId,
    'stored_facts': storedFacts,
    'missing_required': missingRequired,
    'missing_optional': missingOptional,
    if (crossLinks.isNotEmpty) 'cross_links': crossLinks,
    if (summary.isNotEmpty) 'summary': summary,
  };
}
