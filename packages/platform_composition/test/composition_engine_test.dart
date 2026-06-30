import 'package:flutter_test/flutter_test.dart';
import 'package:platform_composition/platform_composition.dart';
import 'package:platform_contracts/platform_contracts.dart';
import 'package:platform_registry/platform_registry.dart';
import 'package:platform_services/platform_services.dart';

class MockMemoryService implements MemoryService {}
class MockManifest implements ExtensionManifest {
  
  const MockManifest({
    required this.identifier,
    required this.version,
    this.minPlatformVersion = '1.0',
    this.metadata = const {},
  });
  @override
  final String identifier;
  @override
  final String version;
  @override
  final String minPlatformVersion;
  @override
  final Map<String, dynamic> metadata;
  
  @override
  List<String> get dependencies => [];
  
  @override
  List<String> get capabilities => [];
  
  @override
  List<String> get permissions => [];
  
  @override
  List<String> get bootstrapTasks => [];
  
  @override
  Map<String, dynamic> get settings => {};
}

class MockRegistry implements ExtensionRegistry {
  @override
  void register(ExtensionManifest manifest) {}

  @override
  List<ExtensionManifest> resolveDependencies() => [];

  @override
  List<ExtensionManifest> getExtensionsByCapability(String capability) => [];

  @override
  ExtensionManifest? getExtension(String identifier) => null;

  @override
  List<ExtensionManifest> getAllManifests() => [];

  @override
  ExtensionManifest? getManifest(String identifier) => null;

  @override
  CapabilityIndex get index => throw UnimplementedError();
}

void main() {
  test('CompositionEngine successfully composes and activates a feature', () {
    final registry = MockRegistry();
    final locator = DefaultServiceLocator();
    final isolationPolicy = DefaultIsolationPolicy();
    
    final engine = CompositionEngine(
      registry: registry,
      locator: locator,
      isolationPolicy: isolationPolicy,
    );

    // Register MemoryService
    locator.register<MemoryService>(MockMemoryService());
    expect(locator.isRegistered<MemoryService>(), isTrue);
    
    const manifest = MockManifest(
      identifier: 'fake.feature',
      version: '1.0',
    );

    // Feature requires MemoryService
    final composed = engine.composeFeature(manifest, [MemoryService]);
    expect(composed, isTrue);
    expect(engine.getFeatureState('fake.feature'), ExtensionLifecycle.composed);
    
    // Activation
    engine.activateFeature('fake.feature');
    expect(engine.getFeatureState('fake.feature'), ExtensionLifecycle.activated);
  });

  test('CompositionEngine fails isolation if service is missing', () {
    final registry = MockRegistry();
    final locator = DefaultServiceLocator();
    final isolationPolicy = DefaultIsolationPolicy();
    
    final engine = CompositionEngine(
      registry: registry,
      locator: locator,
      isolationPolicy: isolationPolicy,
    );

    // We do NOT register KnowledgeService
    
    const manifest = MockManifest(
      identifier: 'fake.feature2',
      version: '1.0',
    );

    expect(
      () => engine.composeFeature(manifest, [KnowledgeService]),
      throwsStateError,
    );
    expect(engine.getFeatureState('fake.feature2'), ExtensionLifecycle.disabled);
  });
}
