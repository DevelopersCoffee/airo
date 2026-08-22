import 'package:meta/meta.dart';

import 'addon_behavior_kind.dart';
import 'addon_id.dart';

const String kAddonManifestSchemaVersion = '1.0';

/// Validated add-on manifest. Supersedes executable plugin entry points.
@immutable
class AddonManifest {
  const AddonManifest({
    required this.schemaVersion,
    required this.id,
    required this.version,
    required this.behaviors,
    required this.capabilities,
    required this.tools,
    this.safetyClass = 'general',
    this.adapterKind,
    this.adapterContract,
    this.workflowTemplateAsset,
    this.workflowSubjectKind,
    this.builtInPriority = 0,
  });

  final String schemaVersion;
  final AddonId id;
  final String version;
  final List<AddonBehaviorKind> behaviors;
  final List<String> capabilities;
  final List<String> tools;
  final String safetyClass;
  final String? adapterKind;
  final String? adapterContract;
  final String? workflowTemplateAsset;
  final String? workflowSubjectKind;
  final int builtInPriority;

  bool hasBehavior(AddonBehaviorKind kind) => behaviors.contains(kind);

  factory AddonManifest.fromJson(Map<String, dynamic> json) {
    final adapter = json['adapter'] as Map<String, dynamic>?;
    final workflow = json['workflow'] as Map<String, dynamic>?;
    return AddonManifest(
      schemaVersion: json['schema_version'] as String,
      id: AddonId(json['id'] as String),
      version: json['version'] as String,
      behaviors: ((json['behaviors'] as List?) ?? const [])
          .map((item) => AddonBehaviorKind.fromJson(item as String))
          .toList(growable: false),
      capabilities: ((json['capabilities'] as List?) ?? const [])
          .map((item) => item as String)
          .toList(growable: false),
      tools: ((json['tools'] as List?) ?? const [])
          .map((item) => item as String)
          .toList(growable: false),
      safetyClass: json['safety_class'] as String? ?? 'general',
      adapterKind: adapter?['kind'] as String?,
      adapterContract: adapter?['contract'] as String?,
      workflowTemplateAsset: workflow?['template_asset'] as String?,
      workflowSubjectKind: workflow?['subject_kind'] as String?,
      builtInPriority: (json['built_in_priority'] as int?) ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
    'schema_version': schemaVersion,
    'id': id.value,
    'version': version,
    'behaviors': behaviors.map((kind) => kind.toJson()).toList(growable: false),
    'capabilities': capabilities,
    'tools': tools,
    'safety_class': safetyClass,
    if (adapterKind != null || adapterContract != null)
      'adapter': {
        if (adapterKind != null) 'kind': adapterKind,
        if (adapterContract != null) 'contract': adapterContract,
      },
    if (workflowTemplateAsset != null || workflowSubjectKind != null)
      'workflow': {
        if (workflowTemplateAsset != null)
          'template_asset': workflowTemplateAsset,
        if (workflowSubjectKind != null) 'subject_kind': workflowSubjectKind,
      },
    if (builtInPriority != 0) 'built_in_priority': builtInPriority,
  };

  @override
  bool operator ==(Object other) =>
      other is AddonManifest && other.id == id && other.version == version;

  @override
  int get hashCode => Object.hash(id, version);

  @override
  String toString() => 'AddonManifest(${id.value}@$version)';
}
