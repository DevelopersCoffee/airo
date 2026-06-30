import 'package:platform_registry/platform_registry.dart';
import 'package:platform_contracts/platform_contracts.dart';

class CapabilityIndex {
  final Map<Capability, List<ExtensionManifest>> _capabilityMap = {};

  void indexManifest(ExtensionManifest manifest) {
    for (final cap in manifest.capabilities) {
      _capabilityMap.putIfAbsent(cap, () => []).add(manifest);
    }
  }

  List<ExtensionManifest> findByCapability(Capability capability) {
    return _capabilityMap[capability] ?? const [];
  }
}
