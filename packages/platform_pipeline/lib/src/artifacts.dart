
abstract class Artifact {
  String get id;
}

class DocumentArtifact implements Artifact {
  @override
  final String id;
  DocumentArtifact(this.id);
}

class AstArtifact implements Artifact {
  @override
  final String id;
  AstArtifact(this.id);
}

class ChunkArtifact implements Artifact {
  @override
  final String id;
  ChunkArtifact(this.id);
}

class EmbeddingArtifact implements Artifact {
  @override
  final String id;
  EmbeddingArtifact(this.id);
}

class IndexArtifact implements Artifact {
  @override
  final String id;
  IndexArtifact(this.id);
}
