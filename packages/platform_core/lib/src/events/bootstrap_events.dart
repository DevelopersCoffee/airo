import 'platform_event.dart';

class BootstrapStartedEvent extends PlatformEvent {
  BootstrapStartedEvent();
}

class BootstrapTaskStartedEvent extends PlatformEvent {
  final String taskId;
  BootstrapTaskStartedEvent(this.taskId);
}

class BootstrapTaskCompletedEvent extends PlatformEvent {
  final String taskId;
  BootstrapTaskCompletedEvent(this.taskId);
}

class BootstrapTaskFailedEvent extends PlatformEvent {
  final String taskId;
  final String error;
  BootstrapTaskFailedEvent(this.taskId, this.error);
}

class BootstrapCompletedEvent extends PlatformEvent {
  BootstrapCompletedEvent();
}

class PlatformReadyEvent extends PlatformEvent {
  PlatformReadyEvent();
}
