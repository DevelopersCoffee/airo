import 'package:flutter_riverpod/misc.dart';
import 'package:go_router/go_router.dart';

import 'app_module.dart';
import 'shell_id.dart';

/// Resolves registered [AppModule]s for one running shell.
///
/// This is the shared replacement for the app-owned static
/// `FeatureRegistry`. Unlike the original, a [ModuleRegistry] is instantiated
/// per shell rather than being a single global static — each shell (mobile,
/// TV, Coins, ...) owns one registry scoped to its own [shell] identifier, so
/// tests and multiple shells never contend over shared static state.
class ModuleRegistry {
  ModuleRegistry({required this.shell});

  /// The shell this registry resolves modules for.
  final ShellId shell;

  final List<AppModule> _modules = [];
  bool _initialized = false;

  /// Registers [module] if it is enabled for [shell]. No-op otherwise.
  void register(AppModule module) {
    if (module.isEnabledForShell(shell)) {
      _modules.add(module);
    }
  }

  /// Initializes every registered module exactly once. A failing module logs
  /// via [onError] (if provided) rather than aborting the remaining modules
  /// or the app's startup.
  Future<void> initializeAll({
    void Function(Object error, AppModule module)? onError,
  }) async {
    if (_initialized) return;

    for (final module in _modules) {
      try {
        await module.initialize();
      } catch (error) {
        onError?.call(error, module);
      }
    }
    _initialized = true;
  }

  /// Disposes every registered module and clears the registry.
  Future<void> disposeAll({
    void Function(Object error, AppModule module)? onError,
  }) async {
    for (final module in _modules) {
      try {
        await module.dispose();
      } catch (error) {
        onError?.call(error, module);
      }
    }
    _modules.clear();
    _initialized = false;
  }

  /// All routes contributed by registered modules for [shell].
  List<RouteBase> get allRoutes =>
      _modules.expand((module) => module.routesFor(shell)).toList();

  /// All provider overrides contributed by registered modules for [shell].
  List<Override> get allProviderOverrides => _modules
      .expand((module) => module.providerOverridesFor(shell))
      .toList();

  /// Read-only snapshot of registered modules.
  List<AppModule> get registeredModules => List.unmodifiable(_modules);

  /// Whether a module with [id] is registered.
  bool isRegistered(String id) => _modules.any((module) => module.id == id);

  /// Number of registered modules.
  int get moduleCount => _modules.length;

  /// Ids of registered modules, in registration order.
  List<String> get moduleIds => _modules.map((module) => module.id).toList();
}
