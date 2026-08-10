import 'package:feature_mind/src/runtime/models/capability_models.dart';
import 'package:feature_mind/src/runtime/ports/capability_port.dart';

/// A controllable [CapabilityPort] double for surface tests.
///
/// [installedResult] and [installedError] let a test choose between the
/// happy path, an empty vault, and a named-port failure without standing up
/// a real runtime. [setActiveCalls] and [removeCalls] record what the
/// screen asked for so a test can assert on intent, not just rendering.
class FakeCapabilityPort implements CapabilityPort {
  FakeCapabilityPort({
    List<InstalledCapability> installedResult = const [],
    this.installedError,
  }) : _installed = List.of(installedResult);

  List<InstalledCapability> _installed;
  Object? installedError;

  final List<({String id, bool active})> setActiveCalls = [];
  final List<String> removeCalls = [];

  @override
  Future<List<InstalledCapability>> installed() async {
    if (installedError != null) throw installedError!;
    return List.unmodifiable(_installed);
  }

  @override
  Future<InstalledCapability?> byId(String id) async {
    for (final capability in await installed()) {
      if (capability.id == id) return capability;
    }
    return null;
  }

  @override
  Future<void> setActive(String id, {required bool active}) async {
    setActiveCalls.add((id: id, active: active));
    _installed = _installed
        .map((c) => c.id == id ? _withActive(c, active) : c)
        .toList();
  }

  @override
  Future<void> remove(String id) async {
    removeCalls.add(id);
    _installed = _installed.where((c) => c.id != id).toList();
  }

  static InstalledCapability _withActive(InstalledCapability c, bool active) {
    return InstalledCapability(
      id: c.id,
      name: c.name,
      version: c.version,
      isFirstParty: c.isFirstParty,
      isActive: active,
      itemCount: c.itemCount,
      safetyClass: c.safetyClass,
      requiresConsentFor: c.requiresConsentFor,
    );
  }
}
