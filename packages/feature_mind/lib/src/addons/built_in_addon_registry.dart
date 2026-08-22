import 'package:core_ai/core_ai.dart';
import 'package:core_domain/core_domain.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'draft_diet_plan/draft_diet_plan_adapter.dart';
import 'generative_addon_coordinator.dart';

/// Built-in add-ons registered for the Mind host.
class BuiltInAddonRegistry {
  BuiltInAddonRegistry._(this.registry, this.coordinator);

  final AddonRegistry registry;
  final GenerativeAddonCoordinator coordinator;

  static BuiltInAddonRegistry create() {
    final registry = AddonRegistry();
    final dietManifest = AddonManifest.fromJson({
      'schema_version': '1.0',
      'id': DraftDietPlanAdapter.addonId,
      'version': '1.0.0',
      'behaviors': ['generative'],
      'capabilities': [
        'conversation.current_turn',
        'conversation.thread_history',
      ],
      'tools': [],
      'safety_class': 'health',
      'adapter': {'kind': 'required_built_in', 'contract': 'generative_v1'},
      'built_in_priority': 10,
    });
    registry.registerBuiltIn(
      manifest: dietManifest,
      generativeAdapter: DraftDietPlanAdapter(),
    );
    registry.setEligibility(
      DraftDietPlanAdapter.addonId,
      const AddonEligibility(
        enabled: true,
        grantedScopes: {
          'conversation.current_turn',
          'conversation.thread_history',
        },
      ),
    );
    return BuiltInAddonRegistry._(
      registry,
      GenerativeAddonCoordinator(registry),
    );
  }
}

final builtInAddonRegistryProvider = Provider<BuiltInAddonRegistry>(
  (ref) => BuiltInAddonRegistry.create(),
);

final generativeAddonCoordinatorProvider = Provider<GenerativeAddonCoordinator>(
  (ref) => ref.watch(builtInAddonRegistryProvider).coordinator,
);

final addonRegistryProvider = Provider<AddonRegistry>(
  (ref) => ref.watch(builtInAddonRegistryProvider).registry,
);
