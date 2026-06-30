import 'dart:async';
import 'package:platform_graph/platform_graph.dart';
import 'package:platform_execution/platform_execution.dart';

class CostModel {
  const CostModel({
    this.latencyMs = 0,
    this.throughputPerSecond = 0,
    this.memoryKb = 0,
    this.batteryMWh = 0,
    this.thermalDelta = 0.0,
    this.storageKb = 0,
    this.networkKbps = 0,
    this.confidence = 1.0,
    this.quality = 1.0,
  });

  final int latencyMs;
  final int throughputPerSecond;
  final int memoryKb;
  final int batteryMWh;
  final double thermalDelta;
  final int storageKb;
  final int networkKbps;
  final double confidence;
  final double quality;
}

class CandidateProvider {
  CandidateProvider(this.id, this.costModel);
  final String id;
  final CostModel costModel;
}

abstract class ExecutionPlanner {
  Future<ExecutionPlan> planExecution(
    dynamic request,
    List<CandidateProvider> candidates,
  );
}

// Ensure PlatformResource etc is still present
abstract class PlatformResource {
  String get id;
}

class CpuResource implements PlatformResource {
  const CpuResource(this.cores, this.numaPreference);
  final int cores;
  final int numaPreference;
  @override String get id => 'cpu';
}

class RamResource implements PlatformResource {
  const RamResource(this.requiredKb);
  final int requiredKb;
  @override String get id => 'ram';
}

class GpuResource implements PlatformResource {
  const GpuResource(this.requiredKb);
  final int requiredKb;
  @override String get id => 'gpu';
}

class NpuResource implements PlatformResource {
  const NpuResource();
  @override String get id => 'npu';
}

class StorageResource implements PlatformResource {
  const StorageResource(this.estimatedIoKb);
  final int estimatedIoKb;
  @override String get id => 'storage';
}

class NetworkResource implements PlatformResource {
  const NetworkResource(this.bandwidthKbps);
  final int bandwidthKbps;
  @override String get id => 'network';
}

class PowerResource implements PlatformResource {
  const PowerResource(this.budgetWatts);
  final int budgetWatts;
  @override String get id => 'power';
}

class ThermalResource implements PlatformResource {
  const ThermalResource(this.budgetCelcius);
  final int budgetCelcius;
  @override String get id => 'thermal';
}

class ResourceRequirements {
  const ResourceRequirements(this.resources, {
    this.priority = 0,
    this.streaming = false,
    this.checkpointable = true,
    this.latencyTargetMs = 0,
    this.deadline,
    this.checkpointIntervalMs = 0,
  });

  final List<PlatformResource> resources;
  
  final int priority;
  final bool streaming;
  final bool checkpointable;
  final int latencyTargetMs;
  final DateTime? deadline;
  final int checkpointIntervalMs;
}

class ExecutionNode extends Node {
  ExecutionNode(this.id, this.requirements);
  @override
  final String id;
  final ResourceRequirements requirements;
}

class ExecutionPlan {
  ExecutionPlan(this.graph);
  final DirectedGraph graph;
}

abstract class ExecutionOptimizer {
  ExecutionPlan optimize(DirectedGraph structuralGraph);
}

abstract class Planner {
  DirectedGraph buildGraph(dynamic manifest);
  ExecutionPlan plan(dynamic manifest, ExecutionOptimizer optimizer) {
    return optimizer.optimize(buildGraph(manifest));
  }
}
