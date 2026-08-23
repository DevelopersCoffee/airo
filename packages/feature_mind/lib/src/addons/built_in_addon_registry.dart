import 'package:core_ai/core_ai.dart';
import 'package:core_domain/core_domain.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'draft_diet_plan/draft_diet_plan_adapter.dart';
import 'generative_addon_coordinator.dart';
import 'graph_workflow/graph_workflow_coordinator.dart';
import 'graph_workflow/car_purchase_graph_adapter.dart';
import 'graph_workflow/hospital_recovery_graph_adapter.dart';
import 'graph_workflow/insurance_planner_graph_adapter.dart';
import 'graph_workflow/property_purchase_graph_adapter.dart';
import 'graph_workflow/university_admission_graph_adapter.dart';

import 'addon_lifecycle_gate.dart';

/// Built-in add-ons registered for the Mind host.
class BuiltInAddonRegistry {
  BuiltInAddonRegistry._({
    required this.registry,
    required this.coordinator,
    required this.graphCoordinator,
  });

  final AddonRegistry registry;
  final GenerativeAddonCoordinator coordinator;
  final GraphWorkflowCoordinator graphCoordinator;

  static void updateEligibility(
    AddonRegistry registry,
    String addonId,
    AddonEligibility eligibility,
  ) {
    registry.setEligibility(addonId, eligibility);
    AddonLifecycleGate().onEligibilityChanged(eligibility);
  }

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
    BuiltInAddonRegistry.updateEligibility(
      registry,
      DraftDietPlanAdapter.addonId,
      const AddonEligibility(
        enabled: true,
        grantedScopes: {
          'conversation.current_turn',
          'conversation.thread_history',
        },
      ),
    );

    _registerGraphAddon(
      registry,
      id: InsurancePlannerGraphAdapter.addonId,
      priority: 20,
      subjectKind: 'claim',
      adapter: InsurancePlannerGraphAdapter(),
      scopes: {
        'conversation.current_turn',
        'graph.addon_scope.read',
      },
      tools: ['query_entity_graph', 'record_lifetrack_facts'],
    );
    _registerGraphAddon(
      registry,
      id: HospitalRecoveryGraphAdapter.addonId,
      priority: 15,
      subjectKind: 'hospital_stay',
      adapter: HospitalRecoveryGraphAdapter(),
      scopes: {
        'conversation.current_turn',
        'graph.addon_scope.read',
      },
      tools: ['query_entity_graph', 'record_lifetrack_facts'],
    );
    _registerGraphAddon(
      registry,
      id: PropertyPurchaseGraphAdapter.addonId,
      priority: 12,
      subjectKind: 'property',
      adapter: PropertyPurchaseGraphAdapter(),
      scopes: {
        'conversation.current_turn',
        'graph.addon_scope.read',
      },
      tools: ['query_entity_graph', 'record_lifetrack_facts'],
    );
    _registerGraphAddon(
      registry,
      id: UniversityAdmissionGraphAdapter.addonId,
      priority: 13,
      subjectKind: 'admission_cycle',
      adapter: UniversityAdmissionGraphAdapter(),
      scopes: {
        'conversation.current_turn',
        'graph.addon_scope.read',
      },
      tools: ['query_entity_graph', 'record_lifetrack_facts'],
    );
    _registerGraphAddon(
      registry,
      id: CarPurchaseGraphAdapter.addonId,
      priority: 11,
      subjectKind: 'car_purchase',
      adapter: CarPurchaseGraphAdapter(),
      scopes: {
        'conversation.current_turn',
        'graph.addon_scope.read',
      },
      tools: ['query_entity_graph', 'record_lifetrack_facts'],
    );

    final graphCoordinator = GraphWorkflowCoordinator(registry);
    return BuiltInAddonRegistry._(
      registry: registry,
      coordinator: GenerativeAddonCoordinator(registry),
      graphCoordinator: graphCoordinator,
    );
  }

  static void _registerGraphAddon(
    AddonRegistry registry, {
    required String id,
    required int priority,
    required String subjectKind,
    required GraphWorkflowAddonAdapter adapter,
    required Set<String> scopes,
    required List<String> tools,
  }) {
    registry.registerBuiltIn(
      manifest: AddonManifest.fromJson({
        'schema_version': '1.0',
        'id': id,
        'version': '1.0.0',
        'behaviors': ['graph_workflow'],
        'capabilities': scopes.toList(growable: false),
        'tools': tools,
        'adapter': {'kind': 'required_built_in', 'contract': 'graph_workflow_v1'},
        'workflow': {'subject_kind': subjectKind},
        'built_in_priority': priority,
      }),
      graphAdapter: adapter,
    );
    BuiltInAddonRegistry.updateEligibility(
      registry,
      id,
      AddonEligibility(enabled: true, grantedScopes: scopes),
    );
  }
}

final builtInAddonRegistryProvider = Provider<BuiltInAddonRegistry>(
  (ref) => BuiltInAddonRegistry.create(),
);

final generativeAddonCoordinatorProvider = Provider<GenerativeAddonCoordinator>(
  (ref) => ref.watch(builtInAddonRegistryProvider).coordinator,
);

final graphWorkflowCoordinatorProvider = Provider<GraphWorkflowCoordinator>(
  (ref) => ref.watch(builtInAddonRegistryProvider).graphCoordinator,
);

final addonRegistryProvider = Provider<AddonRegistry>(
  (ref) => ref.watch(builtInAddonRegistryProvider).registry,
);
