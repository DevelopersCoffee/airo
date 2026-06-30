import 'package:platform_manifest/platform_manifest.dart';

class CapabilityIndex {
  final Map<String, List<ExtensionManifest>> _capabilityMap = {};

  void indexManifest(ExtensionManifest manifest) {
    for (final cap in manifest.capabilities) {
      _capabilityMap.putIfAbsent(cap, () => []).add(manifest);
    }
  }

  List<ExtensionManifest> findByCapability(String capability) {
    return _capabilityMap[capability] ?? const [];
  }
}
