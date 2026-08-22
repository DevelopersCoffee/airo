import '../addons/addon_manifest.dart';

/// Port for add-on registration lookup. Implemented by `core_ai` registry.
abstract interface class AddonRegistryPort {
  AddonManifest? manifestFor(String addonId);

  bool isEnabled(String addonId);

  bool isPinned(String addonId);

  bool hasGrant(String addonId, String scope);
}
