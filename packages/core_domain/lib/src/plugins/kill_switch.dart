/// Runtime plugin kill switch domain models.
///
/// Defines the schema and service contract used to remotely disable plugins
/// for rollback, compliance, deprecation, or targeted rollout scenarios.
library;

import 'package:meta/meta.dart';

/// Runtime kill-switch configuration for all plugins.
@immutable
class PluginKillSwitchConfig {
  const PluginKillSwitchConfig({
    required this.version,
    required this.plugins,
    this.defaultEnabled = true,
  });

  /// Configuration version, normally an ISO-8601 timestamp from the CDN object.
  final String version;

  /// Default state for plugins not explicitly present in [plugins].
  final bool defaultEnabled;

  /// Rules keyed by plugin id, for example `com.airo.plugin.beats`.
  final Map<String, PluginKillSwitchRule> plugins;

  /// Empty allow-all config used before the remote config is fetched.
  static const allowAll = PluginKillSwitchConfig(
    version: 'local-empty',
    plugins: {},
  );

  /// Parse a config from JSON.
  factory PluginKillSwitchConfig.fromJson(Map<String, dynamic> json) {
    final rawPlugins = json['plugins'] as Map<String, dynamic>? ?? const {};
    return PluginKillSwitchConfig(
      version: json['version'] as String? ?? 'unknown',
      defaultEnabled: json['default_enabled'] as bool? ?? true,
      plugins: rawPlugins.map(
        (id, value) => MapEntry(
          id,
          PluginKillSwitchRule.fromJson(
            id,
            value as Map<String, dynamic>? ?? const {},
          ),
        ),
      ),
    );
  }

  /// Convert this config to JSON for CDN/admin tooling.
  Map<String, dynamic> toJson() => {
    'version': version,
    'default_enabled': defaultEnabled,
    'plugins': plugins.map((key, value) => MapEntry(key, value.toJson())),
  };

  /// Return the rule for [pluginId], if one exists.
  PluginKillSwitchRule? ruleFor(String pluginId) => plugins[pluginId];

  /// Whether [pluginId] at [pluginVersion] is enabled by this config.
  bool isPluginEnabled(String pluginId, {String? pluginVersion}) {
    final rule = ruleFor(pluginId);
    if (rule == null) return defaultEnabled;
    return rule.allowsVersion(pluginVersion);
  }

  /// Disabled user-facing message for [pluginId], if currently disabled.
  String? disabledMessageFor(String pluginId, {String? pluginVersion}) {
    final rule = ruleFor(pluginId);
    if (rule == null || rule.allowsVersion(pluginVersion)) return null;
    return rule.message ?? 'This plugin is temporarily unavailable.';
  }
}

/// Per-plugin kill-switch rule.
@immutable
class PluginKillSwitchRule {
  const PluginKillSwitchRule({
    required this.pluginId,
    required this.enabled,
    this.minVersion,
    this.maxVersion,
    this.message,
    this.disabledAt,
    this.etaRestore,
    this.cohort,
  });

  /// Plugin id this rule applies to.
  final String pluginId;

  /// Base enabled state.
  final bool enabled;

  /// Optional minimum version targeted by the rule.
  final String? minVersion;

  /// Optional maximum version targeted by the rule.
  final String? maxVersion;

  /// User-facing disabled message.
  final String? message;

  /// When the plugin was disabled.
  final DateTime? disabledAt;

  /// Estimated restore time shown in runbooks/admin UIs.
  final DateTime? etaRestore;

  /// Optional rollout/cohort label for A/B or regional controls.
  final String? cohort;

  factory PluginKillSwitchRule.fromJson(
    String pluginId,
    Map<String, dynamic> json,
  ) {
    return PluginKillSwitchRule(
      pluginId: pluginId,
      enabled: json['enabled'] as bool? ?? true,
      minVersion: json['min_version'] as String?,
      maxVersion: json['max_version'] as String?,
      message: json['message'] as String?,
      disabledAt: _parseDateTime(json['disabled_at']),
      etaRestore: _parseDateTime(json['eta_restore']),
      cohort: json['cohort'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'enabled': enabled,
    if (minVersion != null) 'min_version': minVersion,
    if (maxVersion != null) 'max_version': maxVersion,
    if (message != null) 'message': message,
    if (disabledAt != null) 'disabled_at': disabledAt!.toIso8601String(),
    if (etaRestore != null) 'eta_restore': etaRestore!.toIso8601String(),
    if (cohort != null) 'cohort': cohort,
  };

  /// Whether this rule allows [pluginVersion].
  ///
  /// If [enabled] is false and [pluginVersion] is inside the optional version
  /// range, the plugin is disabled. Versions outside the targeted range are
  /// allowed so teams can disable only a bad release.
  bool allowsVersion(String? pluginVersion) {
    if (enabled) return true;
    if (pluginVersion == null || (minVersion == null && maxVersion == null)) {
      return false;
    }
    final belowMin =
        minVersion != null && compareVersions(pluginVersion, minVersion!) < 0;
    final aboveMax =
        maxVersion != null && compareVersions(pluginVersion, maxVersion!) > 0;
    return belowMin || aboveMax;
  }
}

/// Update emitted after a refresh succeeds.
@immutable
class KillSwitchUpdate {
  const KillSwitchUpdate({
    required this.config,
    required this.fetchedAt,
    required this.source,
  });

  final PluginKillSwitchConfig config;
  final DateTime fetchedAt;
  final String source;
}

/// Runtime plugin kill-switch contract.
abstract class PluginKillSwitch {
  /// Check whether a plugin is enabled.
  Future<bool> isPluginEnabled(String pluginId, {String? pluginVersion});

  /// Get the disabled message to show to users, if disabled.
  Future<String?> getDisabledMessage(String pluginId, {String? pluginVersion});

  /// Watch successful config refreshes.
  Stream<KillSwitchUpdate> watchUpdates();

  /// Refresh config from the remote source.
  Future<void> refresh();
}

DateTime? _parseDateTime(Object? value) {
  if (value is! String || value.isEmpty) return null;
  return DateTime.tryParse(value);
}

/// Compare dotted semantic-ish versions.
///
/// Non-numeric suffixes are ignored, so `1.2.3-beta1` compares as `1.2.3`.
int compareVersions(String left, String right) {
  final a = _versionParts(left);
  final b = _versionParts(right);
  final maxLength = a.length > b.length ? a.length : b.length;
  for (var i = 0; i < maxLength; i++) {
    final ai = i < a.length ? a[i] : 0;
    final bi = i < b.length ? b[i] : 0;
    if (ai != bi) return ai.compareTo(bi);
  }
  return 0;
}

List<int> _versionParts(String version) => version
    .split('.')
    .map((part) => RegExp(r'^\d+').firstMatch(part)?.group(0) ?? '0')
    .map(int.parse)
    .toList(growable: false);
