/// Plugin Manifest Validator
///
/// Provides validation logic for plugin manifests to ensure they conform
/// to the required schema and constraints.
library;

import 'plugin_manifest.dart';

/// Result of manifest validation
class ManifestValidationResult {
  const ManifestValidationResult({
    required this.isValid,
    this.errors = const [],
    this.warnings = const [],
  });

  /// Whether the manifest is valid
  final bool isValid;

  /// List of validation errors (if any)
  final List<String> errors;

  /// List of validation warnings (non-fatal issues)
  final List<String> warnings;

  /// Create a valid result
  factory ManifestValidationResult.valid({List<String> warnings = const []}) {
    return ManifestValidationResult(isValid: true, warnings: warnings);
  }

  /// Create an invalid result
  factory ManifestValidationResult.invalid(
    List<String> errors, {
    List<String> warnings = const [],
  }) {
    return ManifestValidationResult(
      isValid: false,
      errors: errors,
      warnings: warnings,
    );
  }
}

/// Validator for plugin manifests
class ManifestValidator {
  const ManifestValidator({this.strictMode = true, this.allowedPermissions});

  /// Whether to use strict validation (fail on warnings)
  final bool strictMode;

  /// Optional set of allowed permissions (defaults to all PluginPermission values)
  final Set<PluginPermission>? allowedPermissions;

  /// Validate a plugin manifest
  ManifestValidationResult validate(PluginManifest manifest) {
    final errors = <String>[];
    final warnings = <String>[];

    // Validate schema version
    _validateSchemaVersion(manifest.schemaVersion, errors);

    // Validate plugin ID format (reverse domain notation)
    _validatePluginId(manifest.id, errors);

    // Validate semantic version
    _validateSemanticVersion(manifest.version, errors);
    _validateSemanticVersion(
      manifest.minAppVersion,
      errors,
      fieldName: 'min_app_version',
    );
    if (manifest.maxAppVersion != null) {
      _validateSemanticVersion(
        manifest.maxAppVersion!,
        errors,
        fieldName: 'max_app_version',
      );
    }

    // Validate size
    _validateSize(manifest.sizeMb, errors);

    // Validate entry point
    _validateEntryPoint(manifest.entryPoint, errors);

    // Validate init function
    _validateInitFunction(manifest.initFunction, errors);

    // Validate checksums
    _validateChecksums(manifest.checksums, errors);

    // Validate permissions
    _validatePermissions(manifest.permissions, errors, warnings);

    // Validate dependencies
    _validateDependencies(manifest.dependencies, errors);

    // Validate assets if present
    if (manifest.assets != null) {
      _validateAssets(manifest.assets!, manifest.sizeMb, errors, warnings);
    }

    // Validate feature flags if present
    if (manifest.featureFlags != null) {
      _validateFeatureFlags(manifest.featureFlags!, errors);
    }

    final isValid = errors.isEmpty && (!strictMode || warnings.isEmpty);
    return ManifestValidationResult(
      isValid: isValid,
      errors: errors,
      warnings: warnings,
    );
  }

  void _validateSchemaVersion(String version, List<String> errors) {
    if (version != kManifestSchemaVersion) {
      errors.add(
        'Unsupported schema version: $version (expected $kManifestSchemaVersion)',
      );
    }
  }

  void _validatePluginId(String id, List<String> errors) {
    // Reverse domain notation: com.airo.plugin.name
    final pattern = RegExp(r'^[a-z][a-z0-9]*(\.[a-z][a-z0-9]*)+$');
    if (!pattern.hasMatch(id)) {
      errors.add(
        'Invalid plugin ID format: $id (must be reverse domain notation, e.g., com.airo.plugin.beats)',
      );
    }
    if (!id.startsWith('com.airo.plugin.')) {
      errors.add('Plugin ID must start with "com.airo.plugin."');
    }
  }

  void _validateSemanticVersion(
    String version,
    List<String> errors, {
    String fieldName = 'version',
  }) {
    // Semantic version: MAJOR.MINOR.PATCH
    final pattern = RegExp(r'^(\d+)\.(\d+)\.(\d+)$');
    if (!pattern.hasMatch(version)) {
      errors.add(
        'Invalid $fieldName format: $version (must be MAJOR.MINOR.PATCH)',
      );
    }
  }

  void _validateSize(double sizeMb, List<String> errors) {
    if (sizeMb <= 0) {
      errors.add('Size must be positive: $sizeMb');
    }
    if (sizeMb > 500) {
      errors.add('Plugin size exceeds maximum (500 MB): $sizeMb');
    }
  }

  void _validateEntryPoint(String entryPoint, List<String> errors) {
    if (!entryPoint.endsWith('.dart')) {
      errors.add('Entry point must be a .dart file: $entryPoint');
    }
    if (entryPoint.contains('..')) {
      errors.add('Entry point must not contain path traversal: $entryPoint');
    }
  }

  void _validateInitFunction(String initFunction, List<String> errors) {
    // Valid Dart function name
    final pattern = RegExp(r'^[a-zA-Z_][a-zA-Z0-9_]*$');
    if (!pattern.hasMatch(initFunction)) {
      errors.add('Invalid init function name: $initFunction');
    }
  }

  void _validateChecksums(PluginChecksums checksums, List<String> errors) {
    // SHA-256 hash is 64 hex characters
    final sha256Pattern = RegExp(r'^[a-fA-F0-9]{64}$');
    if (!sha256Pattern.hasMatch(checksums.sha256)) {
      errors.add(
        'Invalid SHA-256 checksum format: ${checksums.sha256} (must be 64 hex characters)',
      );
    }
  }

  void _validatePermissions(
    List<PluginPermission> permissions,
    List<String> errors,
    List<String> warnings,
  ) {
    final allowed = allowedPermissions ?? PluginPermission.values.toSet();
    for (final permission in permissions) {
      if (!allowed.contains(permission)) {
        errors.add('Permission not allowed: ${permission.name}');
      }
    }

    // Check for duplicate permissions
    final seen = <PluginPermission>{};
    for (final permission in permissions) {
      if (!seen.add(permission)) {
        warnings.add('Duplicate permission: ${permission.name}');
      }
    }
  }

  void _validateDependencies(List<String> dependencies, List<String> errors) {
    // Dependency format: package_name>=version or package_name
    final pattern = RegExp(r'^[a-z_][a-z0-9_]*(>=\d+\.\d+\.\d+)?$');
    for (final dep in dependencies) {
      if (!pattern.hasMatch(dep)) {
        errors.add('Invalid dependency format: $dep');
      }
    }
  }

  void _validateAssets(
    PluginAssets assets,
    double pluginSizeMb,
    List<String> errors,
    List<String> warnings,
  ) {
    if (assets.totalSizeMb <= 0) {
      errors.add('Asset size must be positive: ${assets.totalSizeMb}');
    }
    if (assets.totalSizeMb > pluginSizeMb) {
      errors.add(
        'Asset size (${assets.totalSizeMb} MB) exceeds plugin size ($pluginSizeMb MB)',
      );
    }

    // Check for path traversal in asset files
    for (final file in assets.files) {
      if (file.contains('..')) {
        errors.add('Asset path must not contain path traversal: $file');
      }
    }
  }

  void _validateFeatureFlags(PluginFeatureFlags flags, List<String> errors) {
    // Feature flag format: snake_case identifier
    final pattern = RegExp(r'^[a-z][a-z0-9_]*$');

    for (final flag in flags.requires) {
      if (!pattern.hasMatch(flag)) {
        errors.add('Invalid required feature flag format: $flag');
      }
    }

    for (final flag in flags.provides) {
      if (!pattern.hasMatch(flag)) {
        errors.add('Invalid provided feature flag format: $flag');
      }
    }
  }

  /// Validate a registry entry
  ManifestValidationResult validateRegistryEntry(PluginRegistryEntry entry) {
    final errors = <String>[];

    _validatePluginId(entry.id, errors);
    _validateSemanticVersion(
      entry.latestVersion,
      errors,
      fieldName: 'latest_version',
    );

    // Validate URL format
    final downloadUri = Uri.tryParse(entry.downloadUrl);
    if (downloadUri == null || !downloadUri.hasScheme) {
      errors.add('Invalid download URL: ${entry.downloadUrl}');
    }

    if (entry.changelogUrl != null) {
      final changelogUri = Uri.tryParse(entry.changelogUrl!);
      if (changelogUri == null || !changelogUri.hasScheme) {
        errors.add('Invalid changelog URL: ${entry.changelogUrl}');
      }
    }

    return ManifestValidationResult(isValid: errors.isEmpty, errors: errors);
  }

  /// Validate a plugin registry
  ManifestValidationResult validateRegistry(PluginRegistry registry) {
    final errors = <String>[];
    final warnings = <String>[];

    // Validate version format (date-based: YYYY-MM-DD)
    final datePattern = RegExp(r'^\d{4}-\d{2}-\d{2}$');
    if (!datePattern.hasMatch(registry.version)) {
      errors.add(
        'Invalid registry version format: ${registry.version} (expected YYYY-MM-DD)',
      );
    }

    // Validate each entry
    final seenIds = <String>{};
    for (final entry in registry.plugins) {
      final result = validateRegistryEntry(entry);
      errors.addAll(result.errors);

      if (!seenIds.add(entry.id)) {
        errors.add('Duplicate plugin ID in registry: ${entry.id}');
      }
    }

    return ManifestValidationResult(
      isValid: errors.isEmpty,
      errors: errors,
      warnings: warnings,
    );
  }
}
