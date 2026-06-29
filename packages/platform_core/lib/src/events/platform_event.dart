import '../lifecycle/lifecycle_state.dart';

abstract class PlatformEvent {
  final DateTime timestamp;
  PlatformEvent() : timestamp = DateTime.now();
}

class LifecycleEvent extends PlatformEvent {
  final LifecycleState state;
  LifecycleEvent(this.state);
}

class BootstrapEvent extends PlatformEvent {
  final String phase;
  final bool isComplete;
  BootstrapEvent({required this.phase, required this.isComplete});
}

class ErrorEvent extends PlatformEvent {
  final Exception exception;
  final StackTrace? stackTrace;
  ErrorEvent(this.exception, [this.stackTrace]);
}
