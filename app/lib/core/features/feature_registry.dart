/// Feature registry for modular feature management
///
/// This module provides a pattern for registering and managing
/// features that can be conditionally included based on platform.
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

import 'package:flutter_riverpod/misc.dart';
import 'package:go_router/go_router.dart';

import '../config/platform_features.dart';

/// Abstract feature module that can register routes and providers
///
/// Each feature module should extend this class and implement
/// the required methods to integrate with the app.
abstract class AppFeatureModule {
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

  /// Initialize the feature (called once on app startup)
  ///
  /// Override this to perform any async initialization like:
  /// - Loading cached data
  /// - Setting up listeners
  /// - Initializing services
  Future<void> initialize() async {}

  /// Dispose the feature (called on app shutdown)
  ///
  /// Override this to clean up resources like:
  /// - Closing streams
  /// - Cancelling subscriptions
  /// - Releasing native resources
  Future<void> dispose() async {}
}

/// Central registry for all feature modules
///
/// Manages the lifecycle of features and provides
/// aggregated routes and providers.
class FeatureRegistry {
  FeatureRegistry._();

  static final List<AppFeatureModule> _features = [];
  static bool _initialized = false;

  /// Register a feature module
  ///
  /// Only registers if the feature is enabled for the current platform.
  /// Call this in main() before runApp().
  static void register(AppFeatureModule feature) {
    if (feature.isEnabledForPlatform) {
      _features.add(feature);
    }
  }

  /// Initialize all registered features
  ///
  /// Call this after all features are registered.
  static Future<void> initializeAll() async {
    if (_initialized) return;

    for (final feature in _features) {
      try {
        await feature.initialize();
      } catch (e) {
        // Log but don't fail - feature should handle its own errors
        // ignore: avoid_print
        print('Warning: Failed to initialize feature ${feature.name}: $e');
      }
    }
    _initialized = true;
  }

  /// Dispose all registered features
  ///
  /// Call this when the app is shutting down.
  static Future<void> disposeAll() async {
    for (final feature in _features) {
      try {
        await feature.dispose();
      } catch (e) {
        // ignore: avoid_print
        print('Warning: Failed to dispose feature ${feature.name}: $e');
      }
    }
    _features.clear();
    _initialized = false;
  }

  /// Get all routes from registered features
  static List<RouteBase> get allRoutes =>
      _features.expand((f) => f.routes).toList();

  /// Get all provider overrides from registered features
  static List<Override> get allProviderOverrides =>
      _features.expand((f) => f.providerOverrides).toList();

  /// Get all registered features
  static List<AppFeatureModule> get registeredFeatures =>
      List.unmodifiable(_features);

  /// Check if a specific feature is registered
  static bool isRegistered(String name) => _features.any((f) => f.name == name);

  /// Get feature count
  static int get featureCount => _features.length;

  /// Get feature names for logging
  static List<String> get featureNames => _features.map((f) => f.name).toList();
}
