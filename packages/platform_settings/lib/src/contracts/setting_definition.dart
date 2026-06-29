import '../models/settings_namespace.dart';
import '../models/setting_type.dart';
import '../models/setting_flag.dart';
import '../models/setting_metadata.dart';
import 'settings_validator.dart';

abstract interface class SettingDefinition<T> {
  String get key;
  SettingsNamespace get namespace;
  SettingType get type;
  SettingFlag get flag;
  
  T get defaultValue;
  SettingMetadata get metadata;
  
  List<SettingsValidator<T>> get validators;
  
  String get identifier => '${namespace.name}.$key';
}
