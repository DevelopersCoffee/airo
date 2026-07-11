import "pipeline_stage.dart";

class ImportPipeline {
  final List<PipelineStage> stages;

  ImportPipeline(this.stages);

  Future<dynamic> run(dynamic initialInput) async {
    dynamic currentInput = initialInput;
    for (final stage in stages) {
      currentInput = await stage.execute(currentInput);
    }
    return currentInput;
  }
}
