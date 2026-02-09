/// Plugin Loader Service
///
/// Abstract interface for loading and managing plugin lifecycle.
library;

import 'package:meta/meta.dart';
import 'plugin_manifest.dart';

/// Current state of a plugin.
enum PluginState {
  /// Plugin is not installed.
  notInstalled,

  /// Plugin is being downloaded.
  downloading,

  /// Plugin is downloaded but not loaded.
  installed,

  /// Plugin is being loaded.
  loading,

  /// Plugin is loaded and ready.
  loaded,

  /// Plugin is being updated.
  updating,

  /// Plugin is being uninstalled.
  uninstalling,

  /// Plugin encountered an error.
  error,

  /// Plugin is disabled by user.
  disabled,
}

/// Result of loading a plugin.
@immutable
class PluginLoadResult {
  const PluginLoadResult({
    required this.pluginId,
    required this.success,
    this.errorMessage,
    this.loadedVersion,
  });

  /// The plugin ID that was loaded.
  final String pluginId;

  /// Whether the load was successful.
  final bool success;

  /// Error message if load failed.
  final String? errorMessage;

  /// The version that was loaded.
  final String? loadedVersion;

  /// Create a successful result.
  factory PluginLoadResult.success(String pluginId, String version) {
    return PluginLoadResult(
      pluginId: pluginId,
      success: true,
      loadedVersion: version,
    );
  }

  /// Create a failed result.
  factory PluginLoadResult.failure(String pluginId, String error) {
    return PluginLoadResult(
      pluginId: pluginId,
      success: false,
      errorMessage: error,
    );
  }
}

/// Information about a loaded plugin.
@immutable
class LoadedPluginInfo {
  const LoadedPluginInfo({
    required this.manifest,
    required this.state,
    required this.installedAt,
    this.lastLoadedAt,
    this.error,
  });

  /// The plugin manifest.
  final PluginManifest manifest;

  /// Current state of the plugin.
  final PluginState state;

  /// When the plugin was installed.
  final DateTime installedAt;

  /// When the plugin was last loaded.
  final DateTime? lastLoadedAt;

  /// Error message if in error state.
  final String? error;
}

/// Service for loading and managing plugin lifecycle.
abstract class PluginLoaderService {
  /// Load a plugin by ID.
  ///
  /// Downloads and installs the plugin if not already installed,
  /// then loads it into memory.
  Future<PluginLoadResult> loadPlugin(String pluginId);

  /// Unload a plugin from memory.
  ///
  /// The plugin remains installed but is not active.
  Future<void> unloadPlugin(String pluginId);

  /// Check if a plugin is currently loaded.
  bool isLoaded(String pluginId);

  /// Check if a plugin is installed.
  bool isInstalled(String pluginId);

  /// Get the current state of a plugin.
  PluginState getPluginState(String pluginId);

  /// Watch the state of a plugin.
  ///
  /// Returns a stream that emits whenever the plugin state changes.
  Stream<PluginState> watchPluginState(String pluginId);

  /// Get information about a loaded plugin.
  LoadedPluginInfo? getLoadedPluginInfo(String pluginId);

  /// Get all loaded plugins.
  List<LoadedPluginInfo> getLoadedPlugins();

  /// Uninstall a plugin.
  ///
  /// Removes the plugin from storage and unloads it.
  Future<void> uninstallPlugin(String pluginId);

  /// Enable a disabled plugin.
  Future<void> enablePlugin(String pluginId);

  /// Disable a plugin.
  Future<void> disablePlugin(String pluginId);
}
