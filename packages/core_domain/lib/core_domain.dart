// Core domain layer for Airo.
//
// Contains entities, repository interfaces, value objects, and use cases
// that define the business logic of the application.

// Entities
export 'src/entities/entity.dart';
export 'src/entities/user.dart';
export 'src/entities/life_track.dart';
export 'src/entities/life_track_facts.dart';
export 'src/entities/life_track_template.dart';
export 'src/entities/milestone.dart';
export 'src/entities/action_item.dart';
export 'src/entities/input_requirement.dart';

// Result Type - Ok/Err pattern for functional error handling
export 'src/result/result.dart';

// Value Objects
// Failure types for domain errors (hiding base Failure class to avoid conflict with Result.Failure)
export 'src/value_objects/failure.dart' hide Failure;

// Errors
export 'src/errors/app_error.dart';

// Repository Interfaces
export 'src/repositories/repository.dart';
export 'src/repositories/life_track_repository.dart';

// Use Cases
export 'src/use_cases/use_case.dart';
export 'src/use_cases/life_track_use_cases.dart';

// State Management
export 'src/state/async_state.dart';
export 'src/state/paginated_state.dart';
export 'src/state/track_state_machine.dart';

// Graph contracts (neutral entity graph DTOs)
export 'src/graph/entity_graph_node.dart';
export 'src/graph/entity_graph_edge.dart';
export 'src/graph/entity_graph.dart';
export 'src/graph/entity_graph_patch.dart';
export 'src/graph/graph_provenance.dart';

// Add-on contracts
export 'src/addons/addon_id.dart';
export 'src/addons/addon_identity.dart';
export 'src/addons/addon_behavior_kind.dart';
export 'src/addons/addon_manifest.dart';
export 'src/addons/addon_registry_port.dart';

// Workflow projection contracts
export 'src/workflow/offer_decision.dart';
export 'src/workflow/workflow_projection.dart';
export 'src/workflow/pending_assessment.dart';

// Idempotent destination effects
export 'src/effects/idempotent_effect.dart';

// Errors
export 'src/errors/secure_destination_error.dart';

// Plugin System
export 'src/plugins/plugin_manifest.dart';
export 'src/plugins/manifest_validator.dart';
export 'src/plugins/plugin_registry_service.dart';
export 'src/plugins/plugin_loader_service.dart';
export 'src/plugins/plugin_downloader_service.dart';
export 'src/plugins/plugin_storage_service.dart';
export 'src/plugins/kill_switch.dart';
