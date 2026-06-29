import 'package:platform_events/platform_events.dart';
import 'package:platform_core/platform_core.dart' hide PlatformEvent;
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
