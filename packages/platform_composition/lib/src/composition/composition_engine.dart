import 'package:platform_contracts/platform_contracts.dart';
import 'package:platform_registry/platform_registry.dart';

import '../isolation/isolation_policy.dart';
import '../services/service_locator.dart';

class CompositionEngine {

  CompositionEngine({
    required this.registry,
    required this.locator,
    required this.isolationPolicy,
  });
  final ExtensionRegistry registry;
  final ServiceLocator locator;
  final IsolationPolicy isolationPolicy;
  
  final Map<String, ExtensionLifecycle> _states = {};

  bool composeFeature(ExtensionManifest feature, List<Type> requiredServices) {
    if (!isolationPolicy.checkCompatibility(requiredServices, locator)) {
      _states[feature.identifier] = ExtensionLifecycle.disabled;
      throw StateError('Failed to compose feature ${feature.identifier}: Missing required services');
    }
    
    _states[feature.identifier] = ExtensionLifecycle.composed;
    return true;
  }
  
  ExtensionLifecycle getFeatureState(String featureId) {
    return _states[featureId] ?? ExtensionLifecycle.discovered;
  }
  
  void activateFeature(String featureId) {
    if (_states[featureId] != ExtensionLifecycle.composed) {
       throw StateError('Feature $featureId must be composed before activation');
    }
    _states[featureId] = ExtensionLifecycle.activated;
  }
}
