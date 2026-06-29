import '../contracts/settings_registry.dart';
import '../contracts/setting_definition.dart';

class DefaultSettingsRegistry implements SettingsRegistry {
  final Map<String, SettingDefinition<dynamic>> _settings = {};
  bool _locked = false;

  @override
  void register<T>(SettingDefinition<T> setting) {
    if (_locked) {
      throw StateError('SettingsRegistry is locked. Cannot register ${setting.identifier} at runtime.');
    }
    if (_settings.containsKey(setting.identifier)) {
      throw ArgumentError('Setting ${setting.identifier} is already registered.');
    }
    _settings[setting.identifier] = setting;
  }

  @override
  SettingDefinition<T>? getSetting<T>(String identifier) {
    final setting = _settings[identifier];
    if (setting == null) return null;
    if (setting is! SettingDefinition<T>) {
      throw TypeError();
    }
    return setting;
  }

  @override
  List<SettingDefinition<dynamic>> getAll() => _settings.values.toList();

  @override
  void lock() {
    _locked = true;
  }

  @override
  bool get isLocked => _locked;
}
