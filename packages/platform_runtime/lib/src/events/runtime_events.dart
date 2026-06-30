import 'package:platform_core/platform_core.dart' hide PlatformEvent;
import 'package:platform_engine_sdk/platform_engine_sdk.dart';
import 'package:platform_events/platform_events.dart';
import 'package:platform_validation/platform_validation.dart';
import 'package:uuid/uuid.dart';

abstract class _BaseRuntimeEvent implements PlatformEvent {

  _BaseRuntimeEvent({
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
  final String? source = 'platform_runtime';
  @override
  final EventMetadata? metadata = null;
}

class RuntimeRegisteredEvent extends _BaseRuntimeEvent {
  RuntimeRegisteredEvent({required this.descriptor, super.correlationId, super.eventId});
  final EngineDescriptor descriptor;
}

class RuntimeSelectedEvent extends _BaseRuntimeEvent {
  RuntimeSelectedEvent({required this.descriptor, required this.artifact, super.correlationId, super.eventId});
  final EngineDescriptor descriptor;
  final InstalledArtifact artifact;
}

class RuntimeLoadedEvent extends _BaseRuntimeEvent {
  RuntimeLoadedEvent({required this.runtimeSessionId, super.correlationId, super.eventId});
  final String runtimeSessionId;
}

class RuntimeUnloadedEvent extends _BaseRuntimeEvent {
  RuntimeUnloadedEvent({required this.runtimeSessionId, super.correlationId, super.eventId});
  final String runtimeSessionId;
}

class SessionCreatedEvent extends _BaseRuntimeEvent {
  SessionCreatedEvent({required this.session, super.correlationId, super.eventId});
  final EngineSession session;
}

class SessionDestroyedEvent extends _BaseRuntimeEvent {
  SessionDestroyedEvent({required this.runtimeSessionId, super.correlationId, super.eventId});
  final String runtimeSessionId;
}

class ResidencyChangedEvent extends _BaseRuntimeEvent {
  ResidencyChangedEvent({super.correlationId, super.eventId});
}
