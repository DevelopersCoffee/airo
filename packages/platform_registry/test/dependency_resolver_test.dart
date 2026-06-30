import 'package:flutter_test/flutter_test.dart';
import 'package:platform_manifest/platform_manifest.dart';
import 'package:platform_registry/platform_registry.dart';

void main() {
  test('resolves acyclic dependencies correctly', () {
    final resolver = DependencyResolver();
    
    final manifests = [
      const PluginManifest(identifier: 'c', version: '1.0', dependencies: ['b'], minPlatformVersion: '1.0'),
      const PluginManifest(identifier: 'a', version: '1.0', dependencies: [], minPlatformVersion: '1.0'),
      const PluginManifest(identifier: 'b', version: '1.0', dependencies: ['a'], minPlatformVersion: '1.0'),
    ];

    final sorted = resolver.resolveInitializationOrder(manifests);
    expect(sorted.map((e) => e.identifier).toList(), ['a', 'b', 'c']);
  });

  test('throws on cycle', () {
    final resolver = DependencyResolver();
    
    final manifests = [
      const PluginManifest(identifier: 'a', version: '1.0', dependencies: ['b'], minPlatformVersion: '1.0'),
      const PluginManifest(identifier: 'b', version: '1.0', dependencies: ['a'], minPlatformVersion: '1.0'),
    ];

    expect(() => resolver.resolveInitializationOrder(manifests), throwsStateError);
  });
}
