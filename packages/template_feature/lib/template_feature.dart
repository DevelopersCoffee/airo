/// Template feature package
///
/// Copy this package to create a new feature.
/// Rename all occurrences of "template" to your feature name.
library template_feature;

// Domain
export 'src/domain/entities/template_entity.dart';
export 'src/domain/repositories/template_repository.dart';

// Application / Use Cases
export 'src/application/use_cases/get_template_use_case.dart';

// Presentation
export 'src/presentation/screens/template_screen.dart';
export 'src/presentation/providers/template_provider.dart';

