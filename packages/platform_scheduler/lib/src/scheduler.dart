import 'dart:async';
import 'package:platform_identity/platform_identity.dart';

enum ScheduleStrategy {
  fifo,
  priority,
  deadline,
  latencySensitive,
  background,
  batteryAware,
}

class ScheduleRequest {
  const ScheduleRequest({
    required this.taskId,
    required this.strategy,
    this.priority = 0,
    this.deadline,
  });
  final PlatformIdentifier taskId;
  final ScheduleStrategy strategy;
  final int priority;
  final DateTime? deadline;
}

abstract class PlatformScheduler {
  Future<T> schedule<T>(ScheduleRequest request, FutureOr<T> Function() execution);
  void cancel(PlatformIdentifier taskId);
  void pause(PlatformIdentifier taskId);
  void resume(PlatformIdentifier taskId);
}
