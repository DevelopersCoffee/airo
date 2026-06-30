import 'package:platform_manifest/platform_manifest.dart';
import '../indexing/capability_index.dart';

abstract interface class ExtensionRegistry {
  CapabilityIndex get index;
  void register(ExtensionManifest manifest);
  ExtensionManifest? getManifest(String identifier);
  List<ExtensionManifest> getAllManifests();
}
