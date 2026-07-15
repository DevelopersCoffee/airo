import 'dart:async';

import 'entitlements.dart';

/// A unit of pro functionality contributed by the private overlay.
///
/// Modules self-describe which [ProFeature] they implement so the registry
/// can skip initialization when the feature is not entitled.
abstract interface class ProModule {
  /// Stable module id for logs and diagnostics.
  String get id;

  /// The feature this module implements.
  ProFeature get feature;

  /// Called once at app startup, after first frame, when entitled.
  Future<void> initialize();

  /// Called when the module's feature is revoked mid-session.
  Future<void> dispose();
}

/// Collects [ProModule]s contributed at bootstrap and initializes the
/// entitled subset.
class ProModuleRegistry {
  ProModuleRegistry(this._entitlements);

  final Entitlements _entitlements;
  final Map<String, ProModule> _modules = <String, ProModule>{};

  /// Registered module ids, for diagnostics.
  List<String> get moduleIds => List<String>.unmodifiable(_modules.keys);

  /// Registers [module]. Throws [StateError] on duplicate ids so a bad
  /// overlay configuration fails loudly at startup instead of silently
  /// shadowing a module.
  void register(ProModule module) {
    if (_modules.containsKey(module.id)) {
      throw StateError('ProModule "${module.id}" registered twice.');
    }
    _modules[module.id] = module;
  }

  /// Initializes all modules whose feature is entitled. Failures are
  /// isolated per module: one broken module must not take down the rest.
  Future<List<String>> initializeEntitled() async {
    final initialized = <String>[];
    for (final module in _modules.values) {
      if (!_entitlements.isEnabled(module.feature)) continue;
      try {
        await module.initialize();
        initialized.add(module.id);
      } catch (_) {
        // Module-level failure is contained; the open-source baseline
        // experience continues without this module.
      }
    }
    return initialized;
  }
}
