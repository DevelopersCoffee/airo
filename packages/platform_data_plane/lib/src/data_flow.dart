abstract class Artifact {
  String get id;
}

abstract class SourceStage {
  Stream<Artifact> execute();
  String get name;
}
abstract class ParserStage {
  Stream<Artifact> execute(Stream<Artifact> input);
  String get name;
}
abstract class TransformStage {
  Stream<Artifact> execute(Stream<Artifact> input);
  String get name;
}
abstract class ChunkStage {
  Stream<Artifact> execute(Stream<Artifact> input);
  String get name;
}
abstract class EmbedStage {
  Stream<Artifact> execute(Stream<Artifact> input);
  String get name;
}
abstract class IndexStage {
  Stream<Artifact> execute(Stream<Artifact> input);
  String get name;
}
abstract class RetrieveStage {
  Stream<Artifact> execute(Stream<Artifact> input);
  String get name;
}
abstract class GenerateStage {
  Stream<Artifact> execute(Stream<Artifact> input);
  String get name;
}
