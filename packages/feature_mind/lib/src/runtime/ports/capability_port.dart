import '../models/capability_models.dart';

/// Installed capability packs. Packs are declarative data, not code.
///
/// There is no `install` here. Acquiring a pack is milestone 20's marketplace;
/// this port manages what is already on the device.
abstract interface class CapabilityPort {
  Future<List<InstalledCapability>> installed();

  Future<InstalledCapability?> byId(String id);

  Future<void> setActive(String id, {required bool active});

  /// Removes the pack. Contexts it created survive — removing a capability
  /// must not remove a person's data.
  Future<void> remove(String id);
}
