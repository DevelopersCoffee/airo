import 'package:platform_registry/platform_registry.dart';

abstract interface class FeatureLoader {
  Future<List<ExtensionManifest>> discoverFeatures();
}
