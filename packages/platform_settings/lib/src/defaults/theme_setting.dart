import 'package:platform_core/platform_core.dart';
import '../contracts/setting_definition.dart';
import '../contracts/settings_validator.dart';
import '../models/settings_namespace.dart';
import '../models/setting_type.dart';
import '../models/setting_flag.dart';
import '../models/setting_metadata.dart';

class ThemeSetting implements SettingDefinition<String> {
  @override
  String get key => 'theme';

  @override
  SettingsNamespace get namespace => SettingsNamespace.platform;

  @override
  SettingType get type => SettingType.string;

  @override
  SettingFlag get flag => SettingFlag.stable;

  @override
  String get defaultValue => 'system';

  @override
  SettingMetadata get metadata => const SettingMetadata(
    description: 'Application theme preference',
    introducedVersion: SemanticVersion(major: 1, minor: 0, patch: 0),
  );

  @override
  List<SettingsValidator<String>> get validators => [
    _EnumValidator(['system', 'light', 'dark'])
  ];
  
  @override
  String get identifier => '${namespace.name}.$key';
}

class _EnumValidator<T> implements SettingsValidator<T> {
  final List<T> allowedValues;

  _EnumValidator(this.allowedValues);

  @override
  bool isValid(T value) => allowedValues.contains(value);

  @override
  String? get errorMessage => 'Value must be one of $allowedValues';
}
