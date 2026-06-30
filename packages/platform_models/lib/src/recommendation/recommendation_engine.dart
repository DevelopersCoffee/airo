import 'package:platform_models/src/capabilities/model_capabilities.dart';
import 'package:platform_models/src/catalog/model_catalog.dart';
import 'package:platform_models/src/models/model_descriptor.dart';

class ModelConstraints {

  const ModelConstraints({
    required this.modality,
    required this.availableRamMb,
    this.requiresVision = false,
    this.requiresFunctionCalling = false,
  });
  final ModelModality modality;
  final int availableRamMb;
  final bool requiresVision;
  final bool requiresFunctionCalling;
}

class RecommendationEngine {

  const RecommendationEngine(this.catalog);
  final ModelCatalog catalog;

  /// Returns the best model matching the constraints, or null if none match.
  ModelDescriptor? recommend(ModelConstraints constraints) {
    final candidates = catalog.findByModality(constraints.modality).where((m) {
      if (m.minimumRamMb > constraints.availableRamMb) return false;
      if (constraints.requiresVision && !m.capabilities.supportsVision) return false;
      if (constraints.requiresFunctionCalling && !m.capabilities.supportsFunctionCalling) return false;
      return true;
    }).toList();

    if (candidates.isEmpty) return null;

    // Sort by parameter count descending (assume higher parameter count is "better" if it fits in RAM)
    candidates.sort((a, b) => b.parameterCount.compareTo(a.parameterCount));
    
    return candidates.first;
  }
}
