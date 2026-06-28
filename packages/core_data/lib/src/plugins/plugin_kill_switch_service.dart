/// Remote runtime plugin kill switch service.
library;

import 'dart:async';

import 'package:core_domain/core_domain.dart';
import 'package:dio/dio.dart';

/// Fetches plugin kill-switch config from a CDN/HTTP endpoint and caches the
/// latest known-good config in memory.
class RemotePluginKillSwitchService implements PluginKillSwitch {
  RemotePluginKillSwitchService({
    required this.configUrl,
    Dio? dio,
    PluginKillSwitchConfig? initialConfig,
    DateTime Function()? clock,
  }) : _dio = dio ?? Dio(),
       _config = initialConfig ?? PluginKillSwitchConfig.allowAll,
       _clock = clock ?? DateTime.now;

  /// CDN URL containing the kill-switch JSON config.
  final String configUrl;

  final Dio _dio;
  final DateTime Function() _clock;
  final StreamController<KillSwitchUpdate> _updates =
      StreamController<KillSwitchUpdate>.broadcast();

  PluginKillSwitchConfig _config;

  /// Current in-memory config.
  PluginKillSwitchConfig get currentConfig => _config;

  @override
  Future<bool> isPluginEnabled(String pluginId, {String? pluginVersion}) async {
    return _config.isPluginEnabled(pluginId, pluginVersion: pluginVersion);
  }

  @override
  Future<String?> getDisabledMessage(
    String pluginId, {
    String? pluginVersion,
  }) async {
    return _config.disabledMessageFor(pluginId, pluginVersion: pluginVersion);
  }

  @override
  Stream<KillSwitchUpdate> watchUpdates() => _updates.stream;

  @override
  Future<void> refresh() async {
    final response = await _dio.get<Map<String, dynamic>>(
      configUrl,
      options: Options(
        responseType: ResponseType.json,
        headers: const {
          'Accept': 'application/json',
          'Cache-Control': 'max-age=300',
        },
      ),
    );

    final data = response.data;
    if (data == null) {
      throw const PluginKillSwitchException(
        'Empty kill-switch config response',
      );
    }

    final nextConfig = PluginKillSwitchConfig.fromJson(data);
    _config = nextConfig;
    _updates.add(
      KillSwitchUpdate(
        config: nextConfig,
        fetchedAt: _clock(),
        source: configUrl,
      ),
    );
  }

  /// Dispose stream resources when the service is no longer used.
  Future<void> dispose() => _updates.close();
}

/// Wraps an existing [PluginLoaderService] and blocks load attempts when the
/// runtime kill switch disables the requested plugin.
class KillSwitchAwarePluginLoader implements PluginLoaderService {
  KillSwitchAwarePluginLoader({
    required this._delegate,
    required this._killSwitch,
  });

  final PluginLoaderService _delegate;
  final PluginKillSwitch _killSwitch;

  @override
  Future<PluginLoadResult> loadPlugin(String pluginId) async {
    final enabled = await _killSwitch.isPluginEnabled(pluginId);
    if (!enabled) {
      final message = await _killSwitch.getDisabledMessage(pluginId);
      return PluginLoadResult.failure(
        pluginId,
        message ?? 'This plugin is temporarily unavailable.',
      );
    }
    return _delegate.loadPlugin(pluginId);
  }

  @override
  Future<void> unloadPlugin(String pluginId) =>
      _delegate.unloadPlugin(pluginId);

  @override
  bool isLoaded(String pluginId) => _delegate.isLoaded(pluginId);

  @override
  bool isInstalled(String pluginId) => _delegate.isInstalled(pluginId);

  @override
  PluginState getPluginState(String pluginId) {
    return _delegate.getPluginState(pluginId);
  }

  @override
  Stream<PluginState> watchPluginState(String pluginId) {
    return _delegate.watchPluginState(pluginId);
  }

  @override
  LoadedPluginInfo? getLoadedPluginInfo(String pluginId) {
    return _delegate.getLoadedPluginInfo(pluginId);
  }

  @override
  List<LoadedPluginInfo> getLoadedPlugins() => _delegate.getLoadedPlugins();

  @override
  Future<void> uninstallPlugin(String pluginId) {
    return _delegate.uninstallPlugin(pluginId);
  }

  @override
  Future<void> enablePlugin(String pluginId) =>
      _delegate.enablePlugin(pluginId);

  @override
  Future<void> disablePlugin(String pluginId) {
    return _delegate.disablePlugin(pluginId);
  }
}

/// Error thrown when kill-switch config cannot be fetched or parsed.
class PluginKillSwitchException implements Exception {
  const PluginKillSwitchException(this.message);

  final String message;

  @override
  String toString() => 'PluginKillSwitchException: $message';
}
