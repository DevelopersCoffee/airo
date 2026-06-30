
abstract class Artifact {
  String get id;
  String get version;
  String get producer;
  String get schema;
  String get checksum;
  Map<String, dynamic> get metadata;
}

class DocumentArtifact implements Artifact {
  @override final String id;
  @override final String version;
  @override final String producer;
  @override final String schema;
  @override final String checksum;
  @override final Map<String, dynamic> metadata;
  DocumentArtifact({required this.id, required this.version, required this.producer, required this.schema, required this.checksum, this.metadata = const {}});
}

class AstArtifact implements Artifact {
  @override final String id;
  @override final String version;
  @override final String producer;
  @override final String schema;
  @override final String checksum;
  @override final Map<String, dynamic> metadata;
  AstArtifact({required this.id, required this.version, required this.producer, required this.schema, required this.checksum, this.metadata = const {}});
}

class ChunkArtifact implements Artifact {
  @override final String id;
  @override final String version;
  @override final String producer;
  @override final String schema;
  @override final String checksum;
  @override final Map<String, dynamic> metadata;
  ChunkArtifact({required this.id, required this.version, required this.producer, required this.schema, required this.checksum, this.metadata = const {}});
}

class EmbeddingArtifact implements Artifact {
  @override final String id;
  @override final String version;
  @override final String producer;
  @override final String schema;
  @override final String checksum;
  @override final Map<String, dynamic> metadata;
  EmbeddingArtifact({required this.id, required this.version, required this.producer, required this.schema, required this.checksum, this.metadata = const {}});
}

class IndexArtifact implements Artifact {
  @override final String id;
  @override final String version;
  @override final String producer;
  @override final String schema;
  @override final String checksum;
  @override final Map<String, dynamic> metadata;
  IndexArtifact({required this.id, required this.version, required this.producer, required this.schema, required this.checksum, this.metadata = const {}});
}

class ImageArtifact implements Artifact {
  @override final String id;
  @override final String version;
  @override final String producer;
  @override final String schema;
  @override final String checksum;
  @override final Map<String, dynamic> metadata;
  ImageArtifact({required this.id, required this.version, required this.producer, required this.schema, required this.checksum, this.metadata = const {}});
}

class AudioArtifact implements Artifact {
  @override final String id;
  @override final String version;
  @override final String producer;
  @override final String schema;
  @override final String checksum;
  @override final Map<String, dynamic> metadata;
  AudioArtifact({required this.id, required this.version, required this.producer, required this.schema, required this.checksum, this.metadata = const {}});
}

class TensorArtifact implements Artifact {
  @override final String id;
  @override final String version;
  @override final String producer;
  @override final String schema;
  @override final String checksum;
  @override final Map<String, dynamic> metadata;
  TensorArtifact({required this.id, required this.version, required this.producer, required this.schema, required this.checksum, this.metadata = const {}});
}

class ModelArtifact implements Artifact {
  @override final String id;
  @override final String version;
  @override final String producer;
  @override final String schema;
  @override final String checksum;
  @override final Map<String, dynamic> metadata;
  ModelArtifact({required this.id, required this.version, required this.producer, required this.schema, required this.checksum, this.metadata = const {}});
}
