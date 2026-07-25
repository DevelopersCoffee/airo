/// Feature registry for modular feature management
///
/// This module is now a thin, app-owned compatibility shim over the shared,
/// shell-count-agnostic contract in `package:core_product_shell`
/// (`AppModule` / `ModuleRegistry` / `ShellId`). See ADR-0011
/// (`docs/adr/0011-super-app-modular-shell-ssot.md`) — the reusable contract
/// used to live only here, inside `app/`, which blocked other shells (Airo
/// TV, Airo Coins, or any future modular app) from depending on it without
/// importing app-layer code.
///
/// `AppFeatureModule` and `FeatureRegistry` keep their original static API
/// unchanged (same method/property names and signatures) so every existing
/// call site (`main_tv.dart`, `iptv_feature_module.dart`,
/// `music_feature_module.dart`, `app_startup_tasks.dart`) continues to work
/// with no edits. Internally, both now delegate to `core_product_shell`.
///
/// Usage:
/// ```dart
/// // In main.dart
/// FeatureRegistry.register(IptvFeatureModule());
/// FeatureRegistry.register(MusicFeatureModule());
/// FeatureRegistry.initializeAll();
///
/// // Get all routes
/// final routes = FeatureRegistry.allRoutes;
/// ```
library;

import 'package:core_product_shell/core_product_shell.dart' as shell;
import 'package:flutter_riverpod/misc.dart';
import 'package:go_router/go_router.dart';

import '../config/platform_features.dart';

/// Maps the app's existing per-platform feature-toggle axis
/// (`AppPlatform`/`PlatformFeatures`, driven by the `APP_PLATFORM`
/// dart-define) onto the shared [shell.ShellId] contract, so this
/// compatibility layer can delegate to `core_product_shell`'s
/// [shell.ModuleRegistry] without changing today's enablement behavior.
///
/// `AppPlatform.iPad` maps to [shell.ShellId.mobile]: today iPad is a
/// mobile-shaped build variant (same package id as the phone build, just a
/// different UI), not a distinct shell.
shell.ShellId shellIdForPlatform(AppPlatform platform) {
  switch (platform) {
    case AppPlatform.androidTv:
      return shell.ShellId.tv;
    case AppPlatform.mobileFull:
    case AppPlatform.iPad:
      return shell.ShellId.mobile;
  }
}

/// Abstract feature module that can register routes and providers.
///
/// Each feature module should extend this class and implement the required
/// methods to integrate with the app. This class now also implements the
/// shared [shell.AppModule] contract so a [FeatureRegistry] registration
/// forwards straight into a [shell.ModuleRegistry].
abstract class AppFeatureModule implements shell.AppModule {
  /// Unique name for this feature
  String get name;

  /// Feature type for platform checking
  AppFeature get featureType;

  /// Routes provided by this feature
  List<RouteBase> get routes;

  /// Riverpod providers for this feature (optional override)
  List<Override> get providerOverrides => [];

  /// Check if this feature is enabled for the current platform
  bool get isEnabledForPlatform => PlatformFeatures.isEnabled(featureType);

  @override
  String get id => name;

  @override
  Set<shell.ShellId> get supportedShells => {
    shellIdForPlatform(PlatformFeatures.current),
  };

  @override
  bool isEnabledForShell(shell.ShellId shell) =>
      supportedShells.contains(shell);

  @override
  List<RouteBase> routesFor(shell.ShellId shell) => routes;

  @override
  List<Override> providerOverridesFor(shell.ShellId shell) => providerOverrides;

  /// Initialize the feature (called once on app startup)
  ///
  /// Override this to perform any async initialization like:
  /// - Loading cached data
  /// - Setting up listeners
  /// - Initializing services
  @override
  Future<void> initialize() async {}

  /// Dispose the feature (called on app shutdown)
  ///
  /// Override this to clean up resources like:
  /// - Closing streams
  /// - Cancelling subscriptions
  /// - Releasing native resources
  @override
  Future<void> dispose() async {}
}

/// Central registry for all feature modules
///
/// Manages the lifecycle of features and provides aggregated routes and
/// providers. Backed by a single `core_product_shell` `ModuleRegistry`
/// scoped to this app's current shell (derived from `PlatformFeatures`).
class FeatureRegistry {
  FeatureRegistry._();

  static final shell.ModuleRegistry _registry = shell.ModuleRegistry(
    shell: shellIdForPlatform(PlatformFeatures.current),
  );

  /// Register a feature module
  ///
  /// Only registers if the feature is enabled for the current platform.
  /// Call this in main() before runApp().
  static void register(AppFeatureModule feature) {
    if (feature.isEnabledForPlatform) {
      _registry.register(feature);
    }
  }

  /// Initialize all registered features
  ///
  /// Call this after all features are registered.
  static Future<void> initializeAll() => _registry.initializeAll(
    onError: (error, module) =>
        // ignore: avoid_print
        print('Warning: Failed to initialize feature ${module.id}: $error'),
  );

  /// Dispose all registered features
  ///
  /// Call this when the app is shutting down.
  static Future<void> disposeAll() => _registry.disposeAll(
    onError: (error, module) =>
        // ignore: avoid_print
        print('Warning: Failed to dispose feature ${module.id}: $error'),
  );

  /// Get all routes from registered features
  static List<RouteBase> get allRoutes => _registry.allRoutes;

  /// Get all provider overrides from registered features
  static List<Override> get allProviderOverrides =>
      _registry.allProviderOverrides;

  /// Get all registered features
  static List<AppFeatureModule> get registeredFeatures =>
      _registry.registeredModules.cast<AppFeatureModule>();

  /// Check if a specific feature is registered
  static bool isRegistered(String name) => _registry.isRegistered(name);

  /// Get feature count
  static int get featureCount => _registry.moduleCount;

  /// Get feature names for logging
  static List<String> get featureNames => _registry.moduleIds;
}
