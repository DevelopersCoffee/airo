import 'package:platform_core/platform_core.dart' hide PlatformEvent;
import 'package:platform_events/platform_events.dart';
import 'package:platform_hardware/src/compatibility/compatibility_evaluator.dart';
import 'package:platform_hardware/src/platform/hardware_profile.dart';
import 'package:platform_models/platform_models.dart';
import 'package:uuid/uuid.dart';

abstract class _BaseHardwareEvent implements PlatformEvent {

  _BaseHardwareEvent({
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
  final String? source = 'platform_hardware';
  @override
  final EventMetadata? metadata = null;
}

class HardwareDetectedEvent extends _BaseHardwareEvent {
  HardwareDetectedEvent(this.profile, {super.eventId, super.correlationId});
  final HardwareProfile profile;
}

class CompatibilityEvaluatedEvent extends _BaseHardwareEvent {

  CompatibilityEvaluatedEvent(this.profile, this.model, this.report, {super.eventId, super.correlationId});
  final HardwareProfile profile;
  final ModelDescriptor model;
  final CompatibilityReport report;
}

class HardwareProfileUpdatedEvent extends _BaseHardwareEvent {
  HardwareProfileUpdatedEvent(this.profile, {super.eventId, super.correlationId});
  final HardwareProfile profile;
}
