import 'package:flutter_test/flutter_test.dart';
import 'package:platform_manifest/platform_manifest.dart';

void main() {
  test('PluginManifest creation and getters', () {
    const manifest = PluginManifest(
      identifier: 'test.plugin',
      version: '1.0.0',
      minPlatformVersion: '0.2.0',
    );
    expect(manifest.identifier, 'test.plugin');
    expect(manifest.version, '1.0.0');
    expect(manifest.minPlatformVersion, '0.2.0');
    expect(manifest.dependencies, isEmpty);
  });
}
