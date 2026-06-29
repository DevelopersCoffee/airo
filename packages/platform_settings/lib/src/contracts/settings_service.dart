import 'setting_definition.dart';

abstract interface class SettingsService {
  T getValue<T>(SettingDefinition<T> setting);
  Future<void> setValue<T>(SettingDefinition<T> setting, T value);
  Future<void> reset<T>(SettingDefinition<T> setting);
}
