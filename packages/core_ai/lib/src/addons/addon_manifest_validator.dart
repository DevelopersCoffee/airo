import 'package:core_domain/core_domain.dart';
import 'package:meta/meta.dart';

@immutable
class AddonManifestValidationResult {
  const AddonManifestValidationResult._(this.errors);

  const AddonManifestValidationResult.valid() : this._(const []);

  const AddonManifestValidationResult.invalid(List<String> errors)
    : this._(errors);

  final List<String> errors;

  bool get isValid => errors.isEmpty;
}

const Set<String> kKnownAddonCapabilities = {
  'conversation.process',
  'conversation.current_turn',
  'conversation.thread_history',
  'lifetrack.read',
  'lifetrack.write',
  'memory.read',
  'graph.addon_scope.read',
};

const Set<String> kKnownAddonTools = {
  'query_entity_graph',
  'record_lifetrack_facts',
  'query_lifetrack_status',
};

const Set<String> kKnownSafetyClasses = {
  'general',
  'health',
  'financial',
  'identity',
  'education',
};

class AddonManifestValidator {
  const AddonManifestValidator();

  AddonManifestValidationResult validate(Map<String, dynamic> json) {
    final errors = <String>[];

    final schemaVersion = json['schema_version'];
    if (schemaVersion != kAddonManifestSchemaVersion) {
      errors.add('unsupported schema_version: $schemaVersion');
    }

    final id = json['id'];
    if (id is! String || id.trim().isEmpty) {
      errors.add('id is required');
    }

    final version = json['version'];
    if (version is! String || version.trim().isEmpty) {
      errors.add('version is required');
    }

    final behaviors = json['behaviors'];
    if (behaviors is! List || behaviors.isEmpty) {
      errors.add('behaviors must be a non-empty list');
    } else {
      for (final behavior in behaviors) {
        try {
          AddonBehaviorKind.fromJson(behavior as String);
        } on ArgumentError {
          errors.add('unknown behavior: $behavior');
        }
      }
    }

    final capabilities = json['capabilities'];
    if (capabilities is! List) {
      errors.add('capabilities must be a list');
    } else {
      for (final capability in capabilities) {
        if (!kKnownAddonCapabilities.contains(capability)) {
          errors.add('undeclared capability: $capability');
        }
      }
      if (capabilities.contains('memory.write')) {
        errors.add('memory.write is unsupported in this migration');
      }
    }

    final tools = json['tools'];
    if (tools is! List) {
      errors.add('tools must be a list');
    } else {
      for (final tool in tools) {
        if (!kKnownAddonTools.contains(tool)) {
          errors.add('undeclared tool: $tool');
        }
      }
    }

    final safetyClass = json['safety_class'] as String? ?? 'general';
    if (!kKnownSafetyClasses.contains(safetyClass)) {
      errors.add('unknown safety_class: $safetyClass');
    }

    final adapter = json['adapter'] as Map<String, dynamic>?;
    if (adapter != null) {
      final kind = adapter['kind'] as String?;
      if (kind != null && kind != 'required_built_in') {
        errors.add('adapter.kind must be required_built_in when present');
      }
      final contract = adapter['contract'] as String?;
      if (contract != null &&
          contract != 'graph_workflow_v1' &&
          contract != 'generative_v1') {
        errors.add('unknown adapter contract: $contract');
      }
    }

    if (behaviors is List &&
        behaviors.contains('graph_workflow') &&
        json['workflow'] == null) {
      errors.add('graph_workflow behavior requires workflow block');
    }

    return errors.isEmpty
        ? const AddonManifestValidationResult.valid()
        : AddonManifestValidationResult.invalid(errors);
  }

  AddonManifestValidationResult validateManifest(AddonManifest manifest) =>
      validate(manifest.toJson());
}
