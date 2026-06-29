import os

def create_file(path, content):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, 'w', encoding='utf-8') as f:
        f.write(content)

base = 'packages/platform_settings/lib/src'

# Models & Enums
create_file(f'{base}/models/settings_namespace.dart', '''enum SettingsNamespace {
  platform,
  runtime,
  chat,
  memory,
  knowledge,
  meeting,
  workflow,
  download,
  security,
  developer,
  experimental
}
''')

create_file(f'{base}/models/setting_type.dart', '''enum SettingType {
  string,
  integer,
  floating,
  boolean,
  json,
}
''')

create_file(f'{base}/models/setting_flag.dart', '''enum SettingFlag {
  stable,
  experimental,
  developer,
  internal
}
''')

create_file(f'{base}/models/setting_metadata.dart', '''import 'package:platform_core/platform_core.dart';
import 'package:equatable/equatable.dart';

class SettingMetadata extends Equatable {
  final String description;
  final SemanticVersion introducedVersion;
  final SemanticVersion? deprecatedVersion;
  final bool requiresRestart;
  
  const SettingMetadata({
    required this.description,
    required this.introducedVersion,
    this.deprecatedVersion,
    this.requiresRestart = false,
  });

  @override
  List<Object?> get props => [description, introducedVersion, deprecatedVersion, requiresRestart];
}
''')

# Contracts
create_file(f'{base}/contracts/settings_validator.dart', '''abstract interface class SettingsValidator<T> {
  bool isValid(T value);
  String? get errorMessage;
}
''')

create_file(f'{base}/contracts/setting_definition.dart', '''import '../models/settings_namespace.dart';
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
''')

create_file(f'{base}/contracts/settings_registry.dart', '''import 'setting_definition.dart';

abstract interface class SettingsRegistry {
  void register<T>(SettingDefinition<T> setting);
  SettingDefinition<T>? getSetting<T>(String identifier);
  List<SettingDefinition<dynamic>> getAll();
  
  void lock(); // Called after bootstrap to prevent runtime registration
  bool get isLocked;
}
''')

create_file(f'{base}/contracts/settings_service.dart', '''import 'setting_definition.dart';

abstract interface class SettingsService {
  T getValue<T>(SettingDefinition<T> setting);
  Future<void> setValue<T>(SettingDefinition<T> setting, T value);
  Future<void> reset<T>(SettingDefinition<T> setting);
}
''')

create_file(f'{base}/contracts/settings_migration.dart', '''abstract interface class SettingsMigration {
  int get fromVersion;
  int get toVersion;
  Future<void> execute();
}
''')

create_file(f'{base}/contracts/settings_observer.dart', '''import 'setting_definition.dart';

abstract interface class SettingsObserver {
  void onSettingChanged<T>(SettingDefinition<T> setting, T oldValue, T newValue);
}
''')

# Events Integration
create_file(f'{base}/observers/settings_changed_event.dart', '''import 'package:platform_events/platform_events.dart';
import 'package:platform_core/platform_core.dart';
import '../contracts/setting_definition.dart';

class SettingsChangedEvent<T> implements PlatformEvent {
  @override
  final String eventId;
  
  @override
  final DateTime timestamp;
  
  @override
  final EventCategory category = EventCategory.settings;
  
  @override
  final SemanticVersion version = const SemanticVersion(major: 1, minor: 0, patch: 0);

  @override
  final String? correlationId;
  
  @override
  final String? sessionId;
  
  @override
  final String? workspaceId;
  
  @override
  final String? source;
  
  @override
  final EventMetadata? metadata;

  final SettingDefinition<T> setting;
  final T oldValue;
  final T newValue;

  SettingsChangedEvent({
    required this.eventId,
    required this.setting,
    required this.oldValue,
    required this.newValue,
    this.correlationId,
    this.sessionId,
    this.workspaceId,
    this.source,
    this.metadata,
  }) : timestamp = DateTime.now();
}
''')

create_file(f'{base}/observers/event_bus_settings_observer.dart', '''import 'package:uuid/uuid.dart';
import 'package:platform_events/platform_events.dart';
import '../contracts/settings_observer.dart';
import '../contracts/setting_definition.dart';
import 'settings_changed_event.dart';

class EventBusSettingsObserver implements SettingsObserver {
  final EventPublisher _publisher;
  final _uuid = const Uuid();

  EventBusSettingsObserver(this._publisher);

  @override
  void onSettingChanged<T>(SettingDefinition<T> setting, T oldValue, T newValue) {
    _publisher.publish(
      SettingsChangedEvent<T>(
        eventId: _uuid.v4(),
        setting: setting,
        oldValue: oldValue,
        newValue: newValue,
      )
    );
  }
}
''')

# Implementations
create_file(f'{base}/registry/default_settings_registry.dart', '''import '../contracts/settings_registry.dart';
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
''')

create_file(f'{base}/api/memory_settings_service.dart', '''import '../contracts/settings_service.dart';
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
''')

# Concrete setting examples for testing
create_file(f'{base}/defaults/theme_setting.dart', '''import 'package:platform_core/platform_core.dart';
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
''')

# Providers
create_file(f'{base}/providers/settings_providers.dart', '''import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:platform_events/platform_events.dart';
import '../contracts/settings_registry.dart';
import '../contracts/settings_service.dart';
import '../registry/default_settings_registry.dart';
import '../api/memory_settings_service.dart';
import '../observers/event_bus_settings_observer.dart';

final settingsRegistryProvider = Provider<SettingsRegistry>((ref) {
  return DefaultSettingsRegistry();
});

final settingsServiceProvider = Provider<SettingsService>((ref) {
  final registry = ref.watch(settingsRegistryProvider);
  final eventPublisher = ref.watch(eventPublisherProvider);
  
  return MemorySettingsService(
    registry,
    observers: [EventBusSettingsObserver(eventPublisher)],
  );
});
''')

# Export file
create_file('packages/platform_settings/lib/platform_settings.dart', '''library platform_settings;

export 'src/models/settings_namespace.dart';
export 'src/models/setting_type.dart';
export 'src/models/setting_flag.dart';
export 'src/models/setting_metadata.dart';
export 'src/contracts/setting_definition.dart';
export 'src/contracts/settings_registry.dart';
export 'src/contracts/settings_service.dart';
export 'src/contracts/settings_validator.dart';
export 'src/contracts/settings_migration.dart';
export 'src/contracts/settings_observer.dart';
export 'src/observers/settings_changed_event.dart';
export 'src/observers/event_bus_settings_observer.dart';
export 'src/providers/settings_providers.dart';
export 'src/defaults/theme_setting.dart';
''')

print("Created all platform_settings files.")
