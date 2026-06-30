import 'package:platform_contracts/platform_contracts.dart';
import '../plugin/plugin_interface.dart';

class PluginRegistry {
  final Map<String, AiroPlugin> _plugins = {};

  void discover(AiroPlugin plugin) {
    if (plugin.state != ExtensionLifecycle.discovered) {
      throw StateError('Plugin must be in discovered state');
    }
    _plugins[plugin.manifest.identifier] = plugin;
  }

  Future<void> initialize(String identifier) async {
    final plugin = _plugins[identifier];
    if (plugin == null) throw ArgumentError('Plugin not found');
    await plugin.onInitialize();
  }

  Future<void> start(String identifier) async {
    final plugin = _plugins[identifier];
    if (plugin == null) throw ArgumentError('Plugin not found');
    await plugin.onStart();
  }

  Future<void> unload(String identifier) async {
    final plugin = _plugins[identifier];
    if (plugin == null) throw ArgumentError('Plugin not found');
    await plugin.onStop();
    await plugin.onUnload();
    _plugins.remove(identifier);
  }
}
