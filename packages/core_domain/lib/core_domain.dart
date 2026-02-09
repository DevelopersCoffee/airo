/// Core domain layer for Airo
///
/// Contains entities, repository interfaces, value objects, and use cases
/// that define the business logic of the application.
library core_domain;

// Entities
export 'src/entities/entity.dart';
export 'src/entities/user.dart';

// Result Type - Ok/Err pattern for functional error handling
export 'src/result/result.dart';

// Value Objects
// Failure types for domain errors (hiding base Failure class to avoid conflict with Result.Failure)
export 'src/value_objects/failure.dart' hide Failure;

// Errors
export 'src/errors/app_error.dart';

// Repository Interfaces
export 'src/repositories/repository.dart';

// Use Cases
export 'src/use_cases/use_case.dart';

// State Management
export 'src/state/async_state.dart';
export 'src/state/paginated_state.dart';

// Plugin System
export 'src/plugins/plugin_manifest.dart';
export 'src/plugins/manifest_validator.dart';
export 'src/plugins/plugin_registry_service.dart';
export 'src/plugins/plugin_loader_service.dart';
export 'src/plugins/plugin_downloader_service.dart';
export 'src/plugins/plugin_storage_service.dart';
