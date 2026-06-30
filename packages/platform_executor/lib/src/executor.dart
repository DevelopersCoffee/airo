import 'dart:async';
import 'package:platform_execution/platform_execution.dart';
import 'package:platform_graph/platform_graph.dart';

class ExecutionTrace {
  const ExecutionTrace(this.events);
  final List<Map<String, dynamic>> events;
}

abstract class ExecutionEngine {
  Future<ExecutionTrace> execute(ExecutionPlan plan);
  void cancel(String executionId);
  Stream<double> progress(String executionId);
}

class UniversalExecutor implements ExecutionEngine {
  UniversalExecutor(this._scheduler, {this.deterministicMode = false});
  
  final Scheduler _scheduler;
  final bool deterministicMode;

  @override
  Future<ExecutionTrace> execute(ExecutionPlan plan) async {
    // Execute plan via scheduler
    return const ExecutionTrace([]);
  }

  @override
  void cancel(String executionId) {}

  @override
  Stream<double> progress(String executionId) => Stream.value(0.0);
}
