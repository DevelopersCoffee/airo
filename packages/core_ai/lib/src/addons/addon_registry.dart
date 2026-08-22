import 'package:core_domain/core_domain.dart';

import 'addon_eligibility.dart';
import 'addon_manifest_validator.dart';
import 'generative_addon_adapter.dart';
import 'graph_workflow_addon_adapter.dart';

class AddonRegistrationException implements Exception {
  AddonRegistrationException(this.message);

  final String message;

  @override
  String toString() => 'AddonRegistrationException: $message';
}

class AddonRegistry implements AddonRegistryPort {
  AddonRegistry({AddonManifestValidator? validator})
    : _validator = validator ?? const AddonManifestValidator();

  final AddonManifestValidator _validator;
  final Map<String, AddonManifest> _manifests = {};
  final Map<String, GenerativeAddonAdapter> _generativeAdapters = {};
  final Map<String, GraphWorkflowAddonAdapter> _graphAdapters = {};
  final Map<String, AddonEligibility> _eligibility = {};

  List<AddonManifest> get manifests =>
      _manifests.values.toList(growable: false);

  void registerBuiltIn({
    required AddonManifest manifest,
    GenerativeAddonAdapter? generativeAdapter,
    GraphWorkflowAddonAdapter? graphAdapter,
  }) {
    final validation = _validator.validateManifest(manifest);
    if (!validation.isValid) {
      throw AddonRegistrationException(validation.errors.join('; '));
    }

    if (manifest.hasBehavior(AddonBehaviorKind.generative) &&
        generativeAdapter == null) {
      throw AddonRegistrationException(
        'generative behavior requires a built-in adapter',
      );
    }
    if (manifest.hasBehavior(AddonBehaviorKind.graphWorkflow) &&
        graphAdapter == null) {
      throw AddonRegistrationException(
        'graph_workflow behavior requires a built-in adapter',
      );
    }

    final id = manifest.id.value;
    if (_manifests.containsKey(id)) {
      throw AddonRegistrationException('duplicate add-on id: $id');
    }

    _manifests[id] = manifest;
    if (generativeAdapter != null) {
      _generativeAdapters[id] = generativeAdapter;
    }
    if (graphAdapter != null) {
      _graphAdapters[id] = graphAdapter;
    }
    _eligibility.putIfAbsent(id, () => const AddonEligibility());
  }

  @override
  AddonManifest? manifestFor(String addonId) => _manifests[addonId];

  @override
  bool isEnabled(String addonId) => _eligibility[addonId]?.enabled ?? false;

  @override
  bool isPinned(String addonId) => _eligibility[addonId]?.pinned ?? false;

  @override
  bool hasGrant(String addonId, String scope) =>
      _eligibility[addonId]?.hasScope(scope) ?? false;

  void setEligibility(String addonId, AddonEligibility eligibility) {
    if (!_manifests.containsKey(addonId)) {
      throw AddonRegistrationException('unknown add-on: $addonId');
    }
    _eligibility[addonId] = eligibility;
  }

  AddonEligibility eligibilityFor(String addonId) =>
      _eligibility[addonId] ?? const AddonEligibility();

  List<AddonManifest> eligibleManifests({
    AddonBehaviorKind? behavior,
    String requiredScope = 'conversation.current_turn',
  }) {
    final candidates = _manifests.values.where((manifest) {
      if (behavior != null && !manifest.hasBehavior(behavior)) {
        return false;
      }
      final state = _eligibility[manifest.id.value];
      return state != null &&
          state.isEligible &&
          state.hasScope(requiredScope);
    }).toList(growable: false);

    final pinnedList = candidates
        .where((manifest) => _eligibility[manifest.id.value]!.pinned)
        .toList(growable: false);
    final unpinnedList = candidates
        .where((manifest) => !_eligibility[manifest.id.value]!.pinned)
        .toList(growable: false);

    pinnedList.sort(_comparePriority);
    unpinnedList.sort(_comparePriority);
    return [...pinnedList, ...unpinnedList];
  }

  int _comparePriority(AddonManifest a, AddonManifest b) {
    final priorityCompare = b.builtInPriority.compareTo(a.builtInPriority);
    if (priorityCompare != 0) return priorityCompare;
    return a.id.value.compareTo(b.id.value);
  }

  List<GenerativeAddonAdapter> eligibleGenerativeAdapters({
    String requiredScope = 'conversation.current_turn',
  }) {
    return eligibleManifests(
      behavior: AddonBehaviorKind.generative,
      requiredScope: requiredScope,
    )
        .map((manifest) => _generativeAdapters[manifest.id.value])
        .whereType<GenerativeAddonAdapter>()
        .toList(growable: false);
  }

  List<GraphWorkflowAddonAdapter> eligibleGraphAdapters({
    String requiredScope = 'conversation.current_turn',
  }) {
    return eligibleManifests(
      behavior: AddonBehaviorKind.graphWorkflow,
      requiredScope: requiredScope,
    )
        .map((manifest) => _graphAdapters[manifest.id.value])
        .whereType<GraphWorkflowAddonAdapter>()
        .toList(growable: false);
  }

  GenerativeAddonAdapter? generativeAdapterFor(String addonId) =>
      _generativeAdapters[addonId];

  GraphWorkflowAddonAdapter? graphAdapterFor(String addonId) =>
      _graphAdapters[addonId];
}
