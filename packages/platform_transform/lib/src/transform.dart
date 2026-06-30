
abstract class TransformStage<I, O> {
  String get name;
  bool get pure;
  bool get deterministic;
  bool get cacheable;
  bool get parallelizable;
  
  Future<O> transform(I input);
}

class TransformPipeline<I, O> {
  final List<TransformStage> stages;
  TransformPipeline(this.stages);

  Future<O> execute(I input) async {
    dynamic current = input;
    for (var stage in stages) {
      current = await stage.transform(current);
    }
    return current as O;
  }
}
