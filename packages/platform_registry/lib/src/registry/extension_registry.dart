import 'package:platform_registry/platform_registry.dart';
import '../indexing/capability_index.dart';

abstract interface class ExtensionRegistry {
  CapabilityIndex get index;
  void register(ExtensionManifest manifest);
  ExtensionManifest? getManifest(String identifier);
  List<ExtensionManifest> getAllManifests();
}
