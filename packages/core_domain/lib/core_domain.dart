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
export 'src/value_objects/failure.dart';

// Repository Interfaces
export 'src/repositories/repository.dart';

// Use Cases
export 'src/use_cases/use_case.dart';

