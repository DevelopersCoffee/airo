import 'package:core_data/core_data.dart';
import 'package:core_domain/core_domain.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('KillSwitchAwarePluginLoader', () {
    test('blocks disabled plugin and returns user-facing message', () async {
      final delegate = _FakePluginLoader();
      final loader = KillSwitchAwarePluginLoader(
        delegate: delegate,
        killSwitch: _StaticKillSwitch(
          enabled: false,
          message: 'Beats disabled for maintenance',
        ),
      );

      final result = await loader.loadPlugin('com.airo.plugin.beats');

      expect(result.success, isFalse);
      expect(result.errorMessage, 'Beats disabled for maintenance');
      expect(delegate.loadCalls, isEmpty);
    });

    test('delegates load when plugin is enabled', () async {
      final delegate = _FakePluginLoader();
      final loader = KillSwitchAwarePluginLoader(
        delegate: delegate,
        killSwitch: _StaticKillSwitch(enabled: true),
      );

      final result = await loader.loadPlugin('com.airo.plugin.beats');

      expect(result.success, isTrue);
      expect(result.loadedVersion, '1.0.0');
      expect(delegate.loadCalls, ['com.airo.plugin.beats']);
    });
  });
}

class _StaticKillSwitch implements PluginKillSwitch {
  _StaticKillSwitch({required this.enabled, this.message});

  final bool enabled;
  final String? message;

  @override
  Future<String?> getDisabledMessage(
    String pluginId, {
    String? pluginVersion,
  }) async {
    return message;
  }

  @override
  Future<bool> isPluginEnabled(String pluginId, {String? pluginVersion}) async {
    return enabled;
  }

  @override
  Future<void> refresh() async {}

  @override
  Stream<KillSwitchUpdate> watchUpdates() => const Stream.empty();
}

class _FakePluginLoader implements PluginLoaderService {
  final loadCalls = <String>[];

  @override
  Future<PluginLoadResult> loadPlugin(String pluginId) async {
    loadCalls.add(pluginId);
    return PluginLoadResult.success(pluginId, '1.0.0');
  }

  @override
  Future<void> disablePlugin(String pluginId) async {}

  @override
  Future<void> enablePlugin(String pluginId) async {}

  @override
  LoadedPluginInfo? getLoadedPluginInfo(String pluginId) => null;

  @override
  List<LoadedPluginInfo> getLoadedPlugins() => const [];

  @override
  PluginState getPluginState(String pluginId) => PluginState.notInstalled;

  @override
  bool isInstalled(String pluginId) => false;

  @override
  bool isLoaded(String pluginId) => false;

  @override
  Future<void> uninstallPlugin(String pluginId) async {}

  @override
  Future<void> unloadPlugin(String pluginId) async {}

  @override
  Stream<PluginState> watchPluginState(String pluginId) => const Stream.empty();
}
