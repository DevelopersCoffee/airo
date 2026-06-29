import 'package:platform_events/platform_events.dart';
import 'package:platform_core/platform_core.dart' hide PlatformEvent;

class DirectoryCreatedEvent implements PlatformEvent {
  @override
  final String eventId;
  @override
  final DateTime timestamp;
  @override
  final EventCategory category = EventCategory.lifecycle;
  @override
  final SemanticVersion version = const SemanticVersion(major: 1, minor: 0, patch: 0);
  @override
  final String? correlationId;
  @override
  final String? sessionId = null;
  @override
  final String? workspaceId = null;
  @override
  final String? source = 'platform_filesystem';
  @override
  final EventMetadata? metadata = null;

  final String directoryPath;

  DirectoryCreatedEvent({
    required this.eventId,
    required this.directoryPath,
    this.correlationId,
  }) : timestamp = DateTime.now();
}

class FileDeletedEvent implements PlatformEvent {
  @override
  final String eventId;
  @override
  final DateTime timestamp;
  @override
  final EventCategory category = EventCategory.lifecycle;
  @override
  final SemanticVersion version = const SemanticVersion(major: 1, minor: 0, patch: 0);
  @override
  final String? correlationId;
  @override
  final String? sessionId = null;
  @override
  final String? workspaceId;
  @override
  final String? source = 'platform_filesystem';
  @override
  final EventMetadata? metadata = null;

  final String filePath;

  FileDeletedEvent({
    required this.eventId,
    required this.filePath,
    this.workspaceId,
    this.correlationId,
  }) : timestamp = DateTime.now();
}

class CacheClearedEvent implements PlatformEvent {
  @override
  final String eventId;
  @override
  final DateTime timestamp;
  @override
  final EventCategory category = EventCategory.lifecycle;
  @override
  final SemanticVersion version = const SemanticVersion(major: 1, minor: 0, patch: 0);
  @override
  final String? correlationId;
  @override
  final String? sessionId = null;
  @override
  final String? workspaceId = null;
  @override
  final String? source = 'platform_filesystem';
  @override
  final EventMetadata? metadata = null;

  final int bytesFreed;

  CacheClearedEvent({
    required this.eventId,
    required this.bytesFreed,
    this.correlationId,
  }) : timestamp = DateTime.now();
}
