import 'package:platform_core/platform_core.dart' hide PlatformEvent;
import 'package:platform_downloads/platform_downloads.dart';
import 'package:platform_events/platform_events.dart';
import 'package:platform_validation/src/models/installed_artifact.dart';
import 'package:uuid/uuid.dart';

abstract class _BaseValidationEvent implements PlatformEvent {

  _BaseValidationEvent({
    String? eventId,
    this.correlationId,
  }) : eventId = eventId ?? const Uuid().v4(),
       timestamp = DateTime.now();
  @override
  final String eventId;
  @override
  final DateTime timestamp;
  @override
  final EventCategory category = EventCategory.platform;
  @override
  final SemanticVersion version = const SemanticVersion(major: 1, minor: 0, patch: 0);
  @override
  final String? correlationId;
  @override
  final String? sessionId = null;
  @override
  final String? workspaceId = null;
  @override
  final String? source = 'platform_validation';
  @override
  final EventMetadata? metadata = null;
}

class ArtifactValidatedEvent extends _BaseValidationEvent {
  ArtifactValidatedEvent({required this.artifact, super.correlationId, super.eventId});
  final DownloadedArtifact artifact;
}

class ValidationFailedEvent extends _BaseValidationEvent {
  ValidationFailedEvent({required this.artifact, required this.error, super.correlationId, super.eventId});
  final DownloadedArtifact artifact;
  final String error;
}

class InstallationPreparedEvent extends _BaseValidationEvent {
  InstallationPreparedEvent({required this.installationId, super.correlationId, super.eventId});
  final String installationId;
}

class ArtifactInstalledEvent extends _BaseValidationEvent {
  ArtifactInstalledEvent({required this.artifact, super.correlationId, super.eventId});
  final InstalledArtifact artifact;
}
