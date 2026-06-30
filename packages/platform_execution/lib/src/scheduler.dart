import 'dart:async';
import 'package:platform_execution/platform_execution.dart';

class Scheduler {
  const Scheduler({this.deterministicMode = false});
  final bool deterministicMode;

  Future<void> run(ExecutionPlan plan, List<WorkerInstance> workers, List<ExecutionPolicy> policies) async {
    // Schedule nodes based on resource requirements, available workers, and policies.
  }
}
