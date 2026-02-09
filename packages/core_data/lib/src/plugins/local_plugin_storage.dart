/// Local Plugin Storage Implementation
///
/// Concrete implementation of plugin storage using local file system.
library;

import 'dart:convert';
import 'dart:io';
import 'package:core_domain/core_domain.dart';
import 'package:path/path.dart' as path;

/// Local file system implementation of [PluginStorageService].
class LocalPluginStorage implements PluginStorageService {
  LocalPluginStorage({required this.basePath});

  /// Base path for plugin storage.
  final String basePath;

  /// Index file name.
  static const String _indexFileName = 'plugins_index.json';

  /// Plugin data file name.
  static const String _pluginDataFileName = 'plugin.bundle';

  /// Manifest file name.
  static const String _manifestFileName = 'manifest.json';

  /// In-memory cache of stored plugins.
  Map<String, StoredPluginInfo>? _cache;

  /// Get the plugins directory.
  Directory get _pluginsDir => Directory(path.join(basePath, 'plugins'));

  /// Get the index file.
  File get _indexFile => File(path.join(basePath, _indexFileName));

  /// Get the directory for a specific plugin.
  Directory _pluginDir(String pluginId) =>
      Directory(path.join(_pluginsDir.path, pluginId));

  /// Load the index from disk.
  Future<Map<String, StoredPluginInfo>> _loadIndex() async {
    if (_cache != null) return _cache!;

    _cache = {};
    if (!await _indexFile.exists()) return _cache!;

    try {
      final content = await _indexFile.readAsString();
      final json = jsonDecode(content) as Map<String, dynamic>;
      final plugins = json['plugins'] as List<dynamic>? ?? [];

      for (final entry in plugins) {
        final info = _parseStoredPluginInfo(entry as Map<String, dynamic>);
        if (info != null) {
          _cache![info.pluginId] = info;
        }
      }
    } catch (e) {
      // Index corrupted, start fresh
      _cache = {};
    }

    return _cache!;
  }

  /// Save the index to disk.
  Future<void> _saveIndex() async {
    final index = await _loadIndex();
    final plugins = index.values.map(_serializeStoredPluginInfo).toList();
    final json = jsonEncode({'version': 1, 'plugins': plugins});

    await _indexFile.parent.create(recursive: true);
    await _indexFile.writeAsString(json);
  }

  /// Parse a StoredPluginInfo from JSON.
  StoredPluginInfo? _parseStoredPluginInfo(Map<String, dynamic> json) {
    try {
      final manifestJson = json['manifest'] as Map<String, dynamic>;
      final manifest = PluginManifest.fromJson(manifestJson);

      return StoredPluginInfo(
        manifest: manifest,
        installedAt: DateTime.parse(json['installed_at'] as String),
        storagePath: json['storage_path'] as String,
        sizeBytes: json['size_bytes'] as int,
        lastAccessedAt: json['last_accessed_at'] != null
            ? DateTime.parse(json['last_accessed_at'] as String)
            : null,
        isEnabled: json['is_enabled'] as bool? ?? true,
      );
    } catch (e) {
      return null;
    }
  }

  /// Serialize a StoredPluginInfo to JSON.
  Map<String, dynamic> _serializeStoredPluginInfo(StoredPluginInfo info) {
    return {
      'manifest': info.manifest.toJson(),
      'installed_at': info.installedAt.toIso8601String(),
      'storage_path': info.storagePath,
      'size_bytes': info.sizeBytes,
      'last_accessed_at': info.lastAccessedAt?.toIso8601String(),
      'is_enabled': info.isEnabled,
    };
  }

  @override
  Future<StoredPluginInfo> storePlugin(
    List<int> data,
    PluginManifest manifest,
  ) async {
    final pluginDir = _pluginDir(manifest.id);
    await pluginDir.create(recursive: true);

    // Save plugin data
    final dataFile = File(path.join(pluginDir.path, _pluginDataFileName));
    await dataFile.writeAsBytes(data);

    // Save manifest
    final manifestFile = File(path.join(pluginDir.path, _manifestFileName));
    await manifestFile.writeAsString(jsonEncode(manifest.toJson()));

    final info = StoredPluginInfo(
      manifest: manifest,
      installedAt: DateTime.now(),
      storagePath: pluginDir.path,
      sizeBytes: data.length,
      isEnabled: true,
    );

    // Update index
    final index = await _loadIndex();
    index[manifest.id] = info;
    await _saveIndex();

    return info;
  }

  @override
  Future<StoredPluginInfo?> getStoredPlugin(String pluginId) async {
    final index = await _loadIndex();
    return index[pluginId];
  }

  @override
  Future<List<StoredPluginInfo>> getAllStoredPlugins() async {
    final index = await _loadIndex();
    return index.values.toList();
  }

  @override
  Future<bool> isStored(String pluginId) async {
    final index = await _loadIndex();
    return index.containsKey(pluginId);
  }

  @override
  Future<String?> getPluginPath(String pluginId) async {
    final info = await getStoredPlugin(pluginId);
    return info?.storagePath;
  }

  @override
  Future<void> removePlugin(String pluginId) async {
    final index = await _loadIndex();
    final info = index[pluginId];
    if (info == null) return;

    // Remove plugin directory
    final pluginDir = Directory(info.storagePath);
    if (await pluginDir.exists()) {
      await pluginDir.delete(recursive: true);
    }

    // Update index
    index.remove(pluginId);
    await _saveIndex();
  }

  @override
  Future<int> getTotalStorageUsed() async {
    final index = await _loadIndex();
    return index.values.fold<int>(0, (sum, info) => sum + info.sizeBytes);
  }

  @override
  Future<int> getAvailableStorage() async {
    // Returns a reasonable default - actual implementation would check disk space
    // Using 1GB as a reasonable limit for mobile plugins
    const maxPluginStorage = 1024 * 1024 * 1024; // 1GB
    final used = await getTotalStorageUsed();
    return maxPluginStorage - used;
  }

  @override
  Future<void> clearAllPlugins() async {
    // Remove plugins directory
    if (await _pluginsDir.exists()) {
      await _pluginsDir.delete(recursive: true);
    }

    // Clear index
    if (await _indexFile.exists()) {
      await _indexFile.delete();
    }

    _cache = {};
  }

  @override
  Future<void> updateManifest(String pluginId, PluginManifest manifest) async {
    final index = await _loadIndex();
    final info = index[pluginId];
    if (info == null) {
      throw PluginStorageException('Plugin not found: $pluginId');
    }

    // Update manifest file
    final manifestFile = File(path.join(info.storagePath, _manifestFileName));
    await manifestFile.writeAsString(jsonEncode(manifest.toJson()));

    // Update index
    index[pluginId] = StoredPluginInfo(
      manifest: manifest,
      installedAt: info.installedAt,
      storagePath: info.storagePath,
      sizeBytes: info.sizeBytes,
      lastAccessedAt: info.lastAccessedAt,
      isEnabled: info.isEnabled,
    );
    await _saveIndex();
  }

  @override
  Future<void> setPluginEnabled(String pluginId, bool enabled) async {
    final index = await _loadIndex();
    final info = index[pluginId];
    if (info == null) {
      throw PluginStorageException('Plugin not found: $pluginId');
    }

    // Update index
    index[pluginId] = StoredPluginInfo(
      manifest: info.manifest,
      installedAt: info.installedAt,
      storagePath: info.storagePath,
      sizeBytes: info.sizeBytes,
      lastAccessedAt: info.lastAccessedAt,
      isEnabled: enabled,
    );
    await _saveIndex();
  }

  @override
  Future<List<int>?> getPluginData(String pluginId) async {
    final info = await getStoredPlugin(pluginId);
    if (info == null) return null;

    final dataFile = File(path.join(info.storagePath, _pluginDataFileName));
    if (!await dataFile.exists()) return null;

    return dataFile.readAsBytes();
  }
}
