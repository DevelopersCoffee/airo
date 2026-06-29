import '../event_types/event_metadata.dart';
import '../event_types/event_category.dart';
import 'package:platform_core/platform_core.dart' hide PlatformEvent;

abstract interface class PlatformEvent {
  String get eventId;
  DateTime get timestamp;
  EventCategory get category;
  SemanticVersion get version;
  
  String? get correlationId;
  String? get sessionId;
  String? get workspaceId;
  String? get source;
  EventMetadata? get metadata;
}
