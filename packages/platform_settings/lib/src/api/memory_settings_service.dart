import '../contracts/settings_service.dart';
import '../contracts/settings_registry.dart';
import '../contracts/setting_definition.dart';
import '../contracts/settings_observer.dart';

class MemorySettingsService implements SettingsService {
  final SettingsRegistry _registry;
  final List<SettingsObserver> _observers;
  final Map<String, dynamic> _storage = {};

  MemorySettingsService(this._registry, {List<SettingsObserver>? observers})
      : _observers = observers ?? [];

  @override
  T getValue<T>(SettingDefinition<T> setting) {
    final value = _storage[setting.identifier];
    if (value != null) {
      return value as T;
    }
    return setting.defaultValue;
  }

  @override
  Future<void> setValue<T>(SettingDefinition<T> setting, T value) async {
    for (final validator in setting.validators) {
      if (!validator.isValid(value)) {
        throw ArgumentError('Validation failed for ${setting.identifier}: ${validator.errorMessage}');
      }
    }
    
    final oldValue = getValue(setting);
    _storage[setting.identifier] = value;
    
    for (final observer in _observers) {
      observer.onSettingChanged(setting, oldValue, value);
    }
  }

  @override
  Future<void> reset<T>(SettingDefinition<T> setting) async {
    final oldValue = getValue(setting);
    if (_storage.containsKey(setting.identifier)) {
      _storage.remove(setting.identifier);
      
      for (final observer in _observers) {
        observer.onSettingChanged(setting, oldValue, setting.defaultValue);
      }
    }
  }
}
