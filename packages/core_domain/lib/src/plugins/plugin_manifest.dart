/// Plugin Manifest Specification for Airo Super App
///
/// Defines the schema for plugin manifests used in the download-on-demand
/// plugin architecture. Each plugin must include a manifest.json file
/// conforming to this specification.
library;

import 'package:meta/meta.dart';

/// Schema version for the plugin manifest format.
const String kManifestSchemaVersion = '1.0';

/// Represents a plugin manifest with all metadata required for
/// discovery, validation, and loading of plugins.
@immutable
class PluginManifest {
  const PluginManifest({
    required this.schemaVersion,
    required this.id,
    required this.name,
    required this.version,
    required this.sizeMb,
    required this.minAppVersion,
    this.maxAppVersion,
    required this.entryPoint,
    required this.initFunction,
    this.permissions = const [],
    this.dependencies = const [],
    this.assets,
    required this.checksums,
    this.metadata,
    this.featureFlags,
  });

  /// Schema version of this manifest (e.g., "1.0")
  final String schemaVersion;

  /// Unique plugin identifier in reverse domain format
  /// Example: "com.airo.plugin.beats"
  final String id;

  /// Human-readable plugin name
  final String name;

  /// Semantic version (MAJOR.MINOR.PATCH)
  final String version;

  /// Total size in megabytes (must be accurate within 5%)
  final double sizeMb;

  /// Minimum app version required to run this plugin
  final String minAppVersion;

  /// Maximum app version supported (null = no upper limit)
  final String? maxAppVersion;

  /// Entry point Dart file relative to plugin root
  final String entryPoint;

  /// Initialization function name to call on plugin load
  final String initFunction;

  /// Required permissions for this plugin
  final List<PluginPermission> permissions;

  /// Plugin dependencies with version constraints
  final List<String> dependencies;

  /// Asset information for this plugin
  final PluginAssets? assets;

  /// Checksums for integrity verification
  final PluginChecksums checksums;

  /// Optional metadata for display and categorization
  final PluginMetadata? metadata;

  /// Feature flags this plugin requires and provides
  final PluginFeatureFlags? featureFlags;

  /// Creates a PluginManifest from JSON map
  factory PluginManifest.fromJson(Map<String, dynamic> json) {
    return PluginManifest(
      schemaVersion: json['schema_version'] as String,
      id: json['id'] as String,
      name: json['name'] as String,
      version: json['version'] as String,
      sizeMb: (json['size_mb'] as num).toDouble(),
      minAppVersion: json['min_app_version'] as String,
      maxAppVersion: json['max_app_version'] as String?,
      entryPoint: json['entry_point'] as String,
      initFunction: json['init_function'] as String,
      permissions:
          (json['permissions'] as List<dynamic>?)
              ?.map((e) => PluginPermission.fromString(e as String))
              .toList() ??
          [],
      dependencies:
          (json['dependencies'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
      assets: json['assets'] != null
          ? PluginAssets.fromJson(json['assets'] as Map<String, dynamic>)
          : null,
      checksums: PluginChecksums.fromJson(
        json['checksums'] as Map<String, dynamic>,
      ),
      metadata: json['metadata'] != null
          ? PluginMetadata.fromJson(json['metadata'] as Map<String, dynamic>)
          : null,
      featureFlags: json['feature_flags'] != null
          ? PluginFeatureFlags.fromJson(
              json['feature_flags'] as Map<String, dynamic>,
            )
          : null,
    );
  }

  /// Converts this manifest to JSON map
  Map<String, dynamic> toJson() {
    return {
      'schema_version': schemaVersion,
      'id': id,
      'name': name,
      'version': version,
      'size_mb': sizeMb,
      'min_app_version': minAppVersion,
      if (maxAppVersion != null) 'max_app_version': maxAppVersion,
      'entry_point': entryPoint,
      'init_function': initFunction,
      'permissions': permissions.map((e) => e.name).toList(),
      'dependencies': dependencies,
      if (assets != null) 'assets': assets!.toJson(),
      'checksums': checksums.toJson(),
      if (metadata != null) 'metadata': metadata!.toJson(),
      if (featureFlags != null) 'feature_flags': featureFlags!.toJson(),
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PluginManifest &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          version == other.version;

  @override
  int get hashCode => id.hashCode ^ version.hashCode;

  @override
  String toString() => 'PluginManifest($id@$version)';
}

/// Predefined permissions that plugins can request
enum PluginPermission {
  /// Access to audio playback
  audio,

  /// Network access for streaming/API calls
  network,

  /// Background audio playback
  backgroundAudio,

  /// Local file storage access
  storage,

  /// Camera access
  camera,

  /// Microphone access
  microphone,

  /// Location access
  location,

  /// Push notifications
  notifications,

  /// Contacts access
  contacts,

  /// Calendar access
  calendar;

  /// Parse permission from string
  static PluginPermission fromString(String value) {
    return PluginPermission.values.firstWhere(
      (e) => e.name == value || _snakeToCamel(value) == e.name,
      orElse: () => throw ArgumentError('Unknown permission: $value'),
    );
  }

  static String _snakeToCamel(String s) {
    final parts = s.split('_');
    if (parts.length == 1) return s;
    return parts.first +
        parts.skip(1).map((p) => p[0].toUpperCase() + p.substring(1)).join();
  }
}

/// Asset information for a plugin
@immutable
class PluginAssets {
  const PluginAssets({required this.totalSizeMb, this.files = const []});

  /// Total size of all assets in megabytes
  final double totalSizeMb;

  /// List of asset file paths or directories
  final List<String> files;

  factory PluginAssets.fromJson(Map<String, dynamic> json) {
    return PluginAssets(
      totalSizeMb: (json['total_size_mb'] as num).toDouble(),
      files:
          (json['files'] as List<dynamic>?)?.map((e) => e as String).toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() => {
    'total_size_mb': totalSizeMb,
    'files': files,
  };
}

/// Checksums for plugin integrity verification
@immutable
class PluginChecksums {
  const PluginChecksums({required this.sha256, this.signature});

  /// SHA-256 hash of the plugin bundle
  final String sha256;

  /// Optional cryptographic signature for authenticity
  final String? signature;

  factory PluginChecksums.fromJson(Map<String, dynamic> json) {
    return PluginChecksums(
      sha256: json['sha256'] as String,
      signature: json['signature'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'sha256': sha256,
    if (signature != null) 'signature': signature,
  };
}

/// Plugin metadata for display and categorization
@immutable
class PluginMetadata {
  const PluginMetadata({
    this.description,
    this.icon,
    this.category,
    this.tags = const [],
  });

  /// Human-readable description
  final String? description;

  /// Icon asset path
  final String? icon;

  /// Plugin category
  final PluginCategory? category;

  /// Searchable tags
  final List<String> tags;

  factory PluginMetadata.fromJson(Map<String, dynamic> json) {
    return PluginMetadata(
      description: json['description'] as String?,
      icon: json['icon'] as String?,
      category: json['category'] != null
          ? PluginCategory.fromString(json['category'] as String)
          : null,
      tags:
          (json['tags'] as List<dynamic>?)?.map((e) => e as String).toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() => {
    if (description != null) 'description': description,
    if (icon != null) 'icon': icon,
    if (category != null) 'category': category!.name,
    'tags': tags,
  };
}

/// Plugin categories for organization
enum PluginCategory {
  /// Media playback (music, video)
  media,

  /// Games and entertainment
  games,

  /// Productivity tools
  productivity,

  /// Social features
  social,

  /// Finance and money management
  finance,

  /// Education and learning
  education,

  /// Utilities
  utilities,

  /// Communication
  communication;

  /// Parse category from string
  static PluginCategory fromString(String value) {
    return PluginCategory.values.firstWhere(
      (e) => e.name == value,
      orElse: () => throw ArgumentError('Unknown category: $value'),
    );
  }
}

/// Feature flags configuration for a plugin
@immutable
class PluginFeatureFlags {
  const PluginFeatureFlags({
    this.requires = const [],
    this.provides = const [],
  });

  /// Feature flags required for this plugin to be available
  final List<String> requires;

  /// Feature flags this plugin provides when loaded
  final List<String> provides;

  factory PluginFeatureFlags.fromJson(Map<String, dynamic> json) {
    return PluginFeatureFlags(
      requires:
          (json['requires'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
      provides:
          (json['provides'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() => {'requires': requires, 'provides': provides};
}

/// Plugin registry entry for remote plugin discovery
@immutable
class PluginRegistryEntry {
  const PluginRegistryEntry({
    required this.id,
    required this.latestVersion,
    required this.downloadUrl,
    this.changelogUrl,
  });

  /// Plugin identifier
  final String id;

  /// Latest available version
  final String latestVersion;

  /// Download URL for the plugin bundle
  final String downloadUrl;

  /// Optional changelog URL
  final String? changelogUrl;

  factory PluginRegistryEntry.fromJson(Map<String, dynamic> json) {
    return PluginRegistryEntry(
      id: json['id'] as String,
      latestVersion: json['latest_version'] as String,
      downloadUrl: json['download_url'] as String,
      changelogUrl: json['changelog_url'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'latest_version': latestVersion,
    'download_url': downloadUrl,
    if (changelogUrl != null) 'changelog_url': changelogUrl,
  };
}

/// Plugin registry containing available plugins
@immutable
class PluginRegistry {
  const PluginRegistry({required this.version, this.plugins = const []});

  /// Registry version (date-based, e.g., "2026-02-09")
  final String version;

  /// Available plugins
  final List<PluginRegistryEntry> plugins;

  factory PluginRegistry.fromJson(Map<String, dynamic> json) {
    return PluginRegistry(
      version: json['version'] as String,
      plugins:
          (json['plugins'] as List<dynamic>?)
              ?.map(
                (e) => PluginRegistryEntry.fromJson(e as Map<String, dynamic>),
              )
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() => {
    'version': version,
    'plugins': plugins.map((e) => e.toJson()).toList(),
  };

  /// Find a plugin by ID
  PluginRegistryEntry? findById(String id) {
    try {
      return plugins.firstWhere((p) => p.id == id);
    } catch (_) {
      return null;
    }
  }
}
