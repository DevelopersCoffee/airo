abstract class PipelineStage<I, O> {
  String get stageName;
  Future<O> execute(I input);
}
