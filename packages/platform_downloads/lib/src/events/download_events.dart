import 'package:platform_core/platform_core.dart' hide PlatformEvent;
import 'package:platform_downloads/src/manifest/download_manifest.dart';
import 'package:platform_downloads/src/models/download_progress.dart';
import 'package:platform_events/platform_events.dart';
import 'package:uuid/uuid.dart';

abstract class _BaseDownloadEvent implements PlatformEvent {

  _BaseDownloadEvent({
    required this.downloadId, String? eventId,
    this.correlationId,
  }) : eventId = eventId ?? const Uuid().v4(),
       timestamp = DateTime.now();
  @override
  final String eventId;
  @override
  final DateTime timestamp;
  @override
  final EventCategory category = EventCategory.download;
  @override
  final SemanticVersion version = const SemanticVersion(major: 1, minor: 0, patch: 0);
  @override
  final String? correlationId;
  @override
  final String? sessionId = null;
  @override
  final String? workspaceId = null;
  @override
  final String? source = 'platform_downloads';
  @override
  final EventMetadata? metadata = null;

  final String downloadId;
}

class DownloadQueuedEvent extends _BaseDownloadEvent {
  DownloadQueuedEvent({required super.downloadId, required this.manifest, super.correlationId, super.eventId});
  final DownloadManifest manifest;
}

class DownloadStartedEvent extends _BaseDownloadEvent {
  DownloadStartedEvent({required super.downloadId, super.correlationId, super.eventId});
}

class DownloadProgressEvent extends _BaseDownloadEvent {
  DownloadProgressEvent({required super.downloadId, required this.progress, super.correlationId, super.eventId});
  final DownloadProgress progress;
}

class DownloadPausedEvent extends _BaseDownloadEvent {
  DownloadPausedEvent({required super.downloadId, super.correlationId, super.eventId});
}

class DownloadVerifiedEvent extends _BaseDownloadEvent {
  DownloadVerifiedEvent({required super.downloadId, super.correlationId, super.eventId});
}

class DownloadCompletedEvent extends _BaseDownloadEvent {
  DownloadCompletedEvent({required super.downloadId, super.correlationId, super.eventId});
}

class DownloadFailedEvent extends _BaseDownloadEvent {
  DownloadFailedEvent({required super.downloadId, required this.error, super.correlationId, super.eventId});
  final String error;
}

class DownloadCancelledEvent extends _BaseDownloadEvent {
  DownloadCancelledEvent({required super.downloadId, super.correlationId, super.eventId});
}
