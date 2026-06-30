
abstract class TransformStage<I, O> {
  String get name;
  bool get pure;
  bool get deterministic;
  bool get cacheable;
  bool get parallelizable;
  
  Future<O> transform(I input);
}

class TransformPipeline<I, O> {
  TransformPipeline(this.stages);
  final List<TransformStage> stages;

  Future<O> execute(I input) async {
    dynamic current = input;
    for (final stage in stages) {
      current = await stage.transform(current);
    }
    return current as O;
  }
}
