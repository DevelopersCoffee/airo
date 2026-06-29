import 'setting_definition.dart';

abstract interface class SettingsObserver {
  void onSettingChanged<T>(SettingDefinition<T> setting, T oldValue, T newValue);
}
