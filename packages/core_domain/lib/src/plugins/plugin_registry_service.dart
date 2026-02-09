/// Plugin Registry Service
///
/// Abstract interface for discovering and managing available plugins
/// from remote or local sources.
library;

import 'package:meta/meta.dart';
import 'plugin_manifest.dart';

/// Service for discovering and managing available plugins.
///
/// The registry provides a catalog of plugins that can be downloaded
/// and installed. It supports version checking and update detection.
abstract class PluginRegistryService {
  /// Get all available plugins from the registry.
  ///
  /// Returns a list of [PluginManifest] for all plugins that are
  /// available for download.
  Future<List<PluginManifest>> getAvailablePlugins();

  /// Get a specific plugin by its ID.
  ///
  /// Returns the [PluginManifest] for the plugin, or null if not found.
  Future<PluginManifest?> getPlugin(String pluginId);

  /// Check if an update is available for a plugin.
  ///
  /// Compares [currentVersion] with the latest version in the registry.
  /// Returns true if a newer version is available.
  Future<bool> isUpdateAvailable(String pluginId, String currentVersion);

  /// Get the latest version available for a plugin.
  Future<String?> getLatestVersion(String pluginId);

  /// Refresh the plugin registry from the remote source.
  ///
  /// This should be called periodically or on user request to
  /// update the list of available plugins.
  Future<void> refresh();

  /// Search plugins by name or tags.
  Future<List<PluginManifest>> searchPlugins(String query);

  /// Get plugins by category.
  Future<List<PluginManifest>> getPluginsByCategory(PluginCategory category);

  /// Check if offline mode is active (using cached registry).
  bool get isOffline;
}

/// Result of fetching the plugin registry.
@immutable
class PluginRegistryResult {
  const PluginRegistryResult({
    required this.registry,
    required this.fromCache,
    this.lastUpdated,
    this.error,
  });

  /// The plugin registry data.
  final PluginRegistry registry;

  /// Whether the data was loaded from cache.
  final bool fromCache;

  /// When the registry was last updated.
  final DateTime? lastUpdated;

  /// Any error that occurred during fetch.
  final String? error;

  /// Whether the fetch was successful.
  bool get isSuccess => error == null;
}

/// Exception thrown when plugin registry operations fail.
class PluginRegistryException implements Exception {
  const PluginRegistryException(this.message, {this.cause});

  final String message;
  final Object? cause;

  @override
  String toString() =>
      'PluginRegistryException: $message${cause != null ? ' (caused by: $cause)' : ''}';
}
