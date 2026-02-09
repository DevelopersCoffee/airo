/// Plugin Storage Service
///
/// Abstract interface for local plugin storage and management.
library;

import 'package:meta/meta.dart';
import 'plugin_manifest.dart';
import 'plugin_loader_service.dart';

/// Information about a stored plugin.
@immutable
class StoredPluginInfo {
  const StoredPluginInfo({
    required this.manifest,
    required this.installedAt,
    required this.storagePath,
    required this.sizeBytes,
    this.lastAccessedAt,
    this.isEnabled = true,
  });

  /// The plugin manifest.
  final PluginManifest manifest;

  /// When the plugin was installed.
  final DateTime installedAt;

  /// Path to the plugin storage directory.
  final String storagePath;

  /// Size of the stored plugin in bytes.
  final int sizeBytes;

  /// When the plugin was last accessed.
  final DateTime? lastAccessedAt;

  /// Whether the plugin is enabled.
  final bool isEnabled;

  /// Plugin ID shortcut.
  String get pluginId => manifest.id;

  /// Plugin version shortcut.
  String get version => manifest.version;
}

/// Service for managing locally stored plugins.
abstract class PluginStorageService {
  /// Store a downloaded plugin.
  ///
  /// [data] is the raw plugin bundle data.
  /// [manifest] is the plugin manifest.
  Future<StoredPluginInfo> storePlugin(List<int> data, PluginManifest manifest);

  /// Get information about a stored plugin.
  Future<StoredPluginInfo?> getStoredPlugin(String pluginId);

  /// Get all stored plugins.
  Future<List<StoredPluginInfo>> getAllStoredPlugins();

  /// Check if a plugin is stored locally.
  Future<bool> isStored(String pluginId);

  /// Get the storage path for a plugin.
  Future<String?> getPluginPath(String pluginId);

  /// Remove a plugin from storage.
  Future<void> removePlugin(String pluginId);

  /// Get total storage used by plugins.
  Future<int> getTotalStorageUsed();

  /// Get available storage space.
  Future<int> getAvailableStorage();

  /// Clear all plugin storage.
  Future<void> clearAllPlugins();

  /// Update the manifest for a stored plugin.
  Future<void> updateManifest(String pluginId, PluginManifest manifest);

  /// Mark a plugin as enabled/disabled.
  Future<void> setPluginEnabled(String pluginId, bool enabled);

  /// Get the raw data for a stored plugin (for loading).
  Future<List<int>?> getPluginData(String pluginId);
}

/// Exception for plugin storage operations.
class PluginStorageException implements Exception {
  const PluginStorageException(this.message, {this.cause});

  final String message;
  final Object? cause;

  @override
  String toString() =>
      'PluginStorageException: $message${cause != null ? ' (caused by: $cause)' : ''}';
}

/// Plugin manager that coordinates registry, loader, downloader, and storage.
abstract class PluginManager {
  /// Install a plugin from the registry.
  ///
  /// Downloads, verifies, and stores the plugin.
  Future<void> installPlugin(String pluginId);

  /// Update a plugin to the latest version.
  Future<void> updatePlugin(String pluginId);

  /// Check for updates for all installed plugins.
  Future<Map<String, String>> checkForUpdates();

  /// Get all installed plugins with their states.
  Future<List<LoadedPluginInfo>> getInstalledPlugins();

  /// Get the combined status of a plugin.
  Future<LoadedPluginInfo?> getPluginStatus(String pluginId);

  /// Watch all plugin state changes.
  Stream<LoadedPluginInfo> watchAllPluginStates();
}
