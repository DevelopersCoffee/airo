
import 'package:platform_execution/platform_execution.dart';
import 'package:platform_pipeline/platform_pipeline.dart';

class CostEstimator {
  int estimateCost(PipelineStageDescriptor descriptor) => 0;
}

class Optimizer {
  ExecutionGraph optimize(ExecutionGraph graph) => graph;
}

class GraphBuilder {
  ExecutionGraph build(PipelineDag dag) => ExecutionGraph();
}

class Planner {
  final CostEstimator _costEstimator = CostEstimator();
  final Optimizer _optimizer = Optimizer();
  final GraphBuilder _graphBuilder = GraphBuilder();

  ExecutionGraph plan(ExecutionRequest request, PipelineDag pipeline) {
    return _optimizer.optimize(_graphBuilder.build(pipeline));
  }
}
