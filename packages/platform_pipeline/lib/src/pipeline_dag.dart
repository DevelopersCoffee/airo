
class PipelineDag {
  final String name;
  final List<PipelineStage> stages;
  PipelineDag({required this.name, required this.stages});
}

abstract class PipelineStage<I, O> {
  String get name;
  Future<O> execute(I input, PipelineContext context);
}

class PipelineContext {
  final String runId;
  PipelineContext({required this.runId});
}
