import 'package:flutter_test/flutter_test.dart';
import 'package:platform_plugins/platform_plugins.dart';
import 'package:platform_contracts/platform_contracts.dart';
import 'package:platform_manifest/platform_manifest.dart';

class MockPlugin implements AiroPlugin {
  @override
  final PluginManifest manifest = const PluginManifest(
    identifier: 'mock.plugin',
    version: '1.0.0',
    minPlatformVersion: '0.2.0',
  );

  ExtensionLifecycle _state = ExtensionLifecycle.discovered;

  @override
  ExtensionLifecycle get state => _state;

  @override
  Future<void> onInitialize() async {
    _state = ExtensionLifecycle.composed;
  }

  @override
  Future<void> onStart() async {
    _state = ExtensionLifecycle.running;
  }

  @override
  Future<void> onStop() async {
    _state = ExtensionLifecycle.disabled;
  }

  @override
  Future<void> onUnload() async {
    _state = ExtensionLifecycle.unloaded;
  }
}

void main() {
  test('PluginRegistry manages lifecycle', () async {
    final registry = PluginRegistry();
    final plugin = MockPlugin();
    
    registry.discover(plugin);
    expect(plugin.state, ExtensionLifecycle.discovered);

    await registry.initialize('mock.plugin');
    expect(plugin.state, ExtensionLifecycle.composed);

    await registry.start('mock.plugin');
    expect(plugin.state, ExtensionLifecycle.running);

    await registry.unload('mock.plugin');
    expect(plugin.state, ExtensionLifecycle.unloaded);
  });
}
