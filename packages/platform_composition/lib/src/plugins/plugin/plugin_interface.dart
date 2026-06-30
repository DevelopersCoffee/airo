import 'package:platform_registry/platform_registry.dart';
import 'package:platform_contracts/platform_contracts.dart';

abstract interface class AiroPlugin {
  PluginManifest get manifest;
  ExtensionLifecycle get state;

  Future<void> onInitialize();
  Future<void> onStart();
  Future<void> onStop();
  Future<void> onUnload();
}
