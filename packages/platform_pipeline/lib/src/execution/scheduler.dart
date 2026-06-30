import 'dart:async';
import 'package:platform_pipeline/platform_pipeline.dart';

class ExecutionPlan {
  const ExecutionPlan(this.nodes);
  final List<PipelineNode> nodes;
}

class PipelineNode {
  const PipelineNode(this.id, this.dependencies, this.operation);
  final String id;
  final List<String> dependencies;
  final String operation;
}

abstract class PipelinePlanner {
  ExecutionPlan createPlan(List<String> jobs);
}

abstract class Worker {
  Future<void> executeNode(PipelineNode node);
}

class Scheduler {
  Future<void> run(ExecutionPlan plan, List<Worker> workers) async {
    // Scaffold execution
  }
}
