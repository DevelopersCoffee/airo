import 'package:platform_registry/platform_registry.dart';

abstract interface class ExtensionRegistry {
  CapabilityIndex get index;
  void register(ExtensionManifest manifest);
  ExtensionManifest? getManifest(String identifier);
  List<ExtensionManifest> getAllManifests();
}
