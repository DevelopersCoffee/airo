import 'package:platform_manifest/platform_manifest.dart';

abstract interface class FeatureLoader {
  Future<List<ExtensionManifest>> discoverFeatures();
}
