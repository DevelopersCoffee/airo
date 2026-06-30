import 'package:platform_models/src/capabilities/model_capabilities.dart';
import 'package:platform_models/src/models/model_descriptor.dart';

abstract interface class ModelCatalog {
  Future<void> initialize();
  List<ModelDescriptor> get availableModels;
  ModelDescriptor? findById(String identifier);
  List<ModelDescriptor> findByFamily(String family);
  List<ModelDescriptor> findByModality(ModelModality modality);
}

class InMemoryModelCatalog implements ModelCatalog {
  final List<ModelDescriptor> _models = [];

  void addModel(ModelDescriptor descriptor) {
    _models.add(descriptor);
  }

  @override
  Future<void> initialize() async {
    // In WP-1.1, we start with an empty or manually injected registry.
  }

  @override
  List<ModelDescriptor> get availableModels => List.unmodifiable(_models);

  @override
  ModelDescriptor? findById(String identifier) {
    try {
      return _models.firstWhere((m) => m.identifier == identifier);
    } catch (_) {
      return null;
    }
  }

  @override
  List<ModelDescriptor> findByFamily(String family) {
    return _models.where((m) => m.family == family).toList();
  }

  @override
  List<ModelDescriptor> findByModality(ModelModality modality) {
    return _models.where((m) => m.modality == modality).toList();
  }
}
