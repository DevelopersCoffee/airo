import 'package:flutter_riverpod/misc.dart';
import 'package:go_router/go_router.dart';

import 'app_module.dart';
import 'shell_id.dart';

/// Thrown when two enabled modules make the product composition ambiguous.
class ModuleCompositionException implements Exception {
  const ModuleCompositionException(this.message);

  final String message;

  @override
  String toString() => 'ModuleCompositionException: $message';
}

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
  ///
  /// Enabled modules must have unique IDs, top-level route paths, and route
  /// names. Product composition is resolved before `runApp`, so ambiguity is
  /// reported immediately instead of depending on router ordering.
  void register(AppModule module) {
    if (!module.isEnabledForShell(shell)) return;

    final duplicateId = _modules.any((existing) => existing.id == module.id);
    if (duplicateId) {
      throw ModuleCompositionException(
        'Duplicate module id "${module.id}" for shell "${shell.value}".',
      );
    }

    final existingRoutes = _modules
        .expand((existing) => _routeIdentities(existing.routesFor(shell)))
        .toList(growable: false);
    final candidateRoutes = _routeIdentities(module.routesFor(shell));

    for (final candidate in candidateRoutes) {
      final conflictingPath = existingRoutes
          .where((route) => route.path == candidate.path)
          .firstOrNull;
      if (conflictingPath != null) {
        throw ModuleCompositionException(
          'Duplicate route path "${candidate.path}" for shell '
          '"${shell.value}" while registering module "${module.id}".',
        );
      }

      final candidateName = candidate.name;
      if (candidateName == null) continue;
      final conflictingName = existingRoutes
          .where((route) => route.name == candidateName)
          .firstOrNull;
      if (conflictingName != null) {
        throw ModuleCompositionException(
          'Duplicate route name "$candidateName" for shell '
          '"${shell.value}" while registering module "${module.id}".',
        );
      }
    }

    _modules.add(module);
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

  /// Routes contributed by the registered module identified by [moduleId].
  ///
  /// Shells use this when a module's routes must be mounted inside a specific
  /// navigation branch rather than appended to the router's top-level list.
  /// An absent module returns an empty bundle so optional modules stay
  /// straightforward to compose.
  List<RouteBase> routesForModule(String moduleId) {
    final module = _modules
        .where((candidate) => candidate.id == moduleId)
        .firstOrNull;
    return module?.routesFor(shell).toList(growable: false) ?? const [];
  }

  /// All provider overrides contributed by registered modules for [shell].
  List<Override> get allProviderOverrides =>
      _modules.expand((module) => module.providerOverridesFor(shell)).toList();

  /// Read-only snapshot of registered modules.
  List<AppModule> get registeredModules => List.unmodifiable(_modules);

  /// Whether a module with [id] is registered.
  bool isRegistered(String id) => _modules.any((module) => module.id == id);

  /// Number of registered modules.
  int get moduleCount => _modules.length;

  /// Ids of registered modules, in registration order.
  List<String> get moduleIds => _modules.map((module) => module.id).toList();
}

class _RouteIdentity {
  const _RouteIdentity({required this.path, required this.name});

  final String path;
  final String? name;
}

Iterable<_RouteIdentity> _routeIdentities(
  Iterable<RouteBase> routes, [
  String parentPath = '',
]) sync* {
  for (final route in routes) {
    var childParentPath = parentPath;
    if (route case final GoRoute goRoute) {
      final path = goRoute.path.startsWith('/')
          ? goRoute.path
          : '$parentPath/${goRoute.path}'.replaceAll('//', '/');
      childParentPath = path;
      yield _RouteIdentity(path: path, name: goRoute.name);
    }
    yield* _routeIdentities(route.routes, childParentPath);
  }
}
