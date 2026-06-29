import 'package:platform_events/platform_events.dart';
import 'package:platform_core/platform_core.dart' hide PlatformEvent;

abstract class _BaseJobEvent implements PlatformEvent {
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
  final String? source = 'platform_jobs';
  @override
  final EventMetadata? metadata = null;

  final String jobId;
  final String jobName;

  _BaseJobEvent({
    required this.eventId,
    required this.jobId,
    required this.jobName,
    this.correlationId,
  }) : timestamp = DateTime.now();
}

class JobQueuedEvent extends _BaseJobEvent {
  JobQueuedEvent({required super.eventId, required super.jobId, required super.jobName, super.correlationId});
}

class JobStartedEvent extends _BaseJobEvent {
  JobStartedEvent({required super.eventId, required super.jobId, required super.jobName, super.correlationId});
}

class JobProgressEvent extends _BaseJobEvent {
  final double progress; // 0.0 to 1.0
  JobProgressEvent({required super.eventId, required super.jobId, required super.jobName, required this.progress, super.correlationId});
}

class JobSucceededEvent extends _BaseJobEvent {
  JobSucceededEvent({required super.eventId, required super.jobId, required super.jobName, super.correlationId});
}

class JobFailedEvent extends _BaseJobEvent {
  final String error;
  JobFailedEvent({required super.eventId, required super.jobId, required super.jobName, required this.error, super.correlationId});
}

class JobCancelledEvent extends _BaseJobEvent {
  JobCancelledEvent({required super.eventId, required super.jobId, required super.jobName, super.correlationId});
}

class JobRetriedEvent extends _BaseJobEvent {
  final int attempt;
  JobRetriedEvent({required super.eventId, required super.jobId, required super.jobName, required this.attempt, super.correlationId});
}
