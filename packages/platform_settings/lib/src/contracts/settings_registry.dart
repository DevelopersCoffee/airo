import 'setting_definition.dart';

abstract interface class SettingsRegistry {
  void register<T>(SettingDefinition<T> setting);
  SettingDefinition<T>? getSetting<T>(String identifier);
  List<SettingDefinition<dynamic>> getAll();
  
  void lock(); // Called after bootstrap to prevent runtime registration
  bool get isLocked;
}
