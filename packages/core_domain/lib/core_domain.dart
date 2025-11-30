/// Core domain layer for Airo
///
/// Contains entities, repository interfaces, value objects, and use cases
/// that define the business logic of the application.
library core_domain;

// Entities
export 'src/entities/entity.dart';
export 'src/entities/user.dart';

// Value Objects
export 'src/value_objects/result.dart';
// Note: Failure class from failure.dart conflicts with Failure<T> from result.dart
// Use 'hide' to avoid the conflict - import failure.dart directly if needed
export 'src/value_objects/failure.dart' hide Failure;

// Errors
export 'src/errors/app_error.dart';

// Repository Interfaces
export 'src/repositories/repository.dart';

// Use Cases
export 'src/use_cases/use_case.dart';
