import 'package:flutter_test/flutter_test.dart';
import 'package:platform_manifest/platform_manifest.dart';
import 'package:platform_registry/platform_registry.dart';
import 'package:platform_contracts/platform_contracts.dart';

void main() {
  test('indexes and finds by capability', () {
    final index = CapabilityIndex();
    
    const m1 = EngineManifest(
      identifier: 'engine1',
      version: '1.0',
      capabilities: [Capability(domain: CapabilityDomain.engine, name: 'supports_vision')],
      minPlatformVersion: '1.0'
    );
    
    const m2 = ToolManifest(
      identifier: 'tool1',
      version: '1.0',
      capabilities: [
        Capability(domain: CapabilityDomain.engine, name: 'supports_vision'),
        Capability(domain: CapabilityDomain.engine, name: 'supports_audio')
      ],
      minPlatformVersion: '1.0'
    );

    index.indexManifest(m1);
    index.indexManifest(m2);

    final visionProviders = index.findByCapability(const Capability(domain: CapabilityDomain.engine, name: 'supports_vision'));
    expect(visionProviders.length, 2);
    
    final audioProviders = index.findByCapability(const Capability(domain: CapabilityDomain.engine, name: 'supports_audio'));
    expect(audioProviders.length, 1);
    expect(audioProviders.first.identifier, 'tool1');
  });
}
