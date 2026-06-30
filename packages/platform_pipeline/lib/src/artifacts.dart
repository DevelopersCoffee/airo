
class ArtifactMetadata {
  final Map<String, dynamic> data;
  ArtifactMetadata([this.data = const {}]);
}

abstract interface class Artifact<T> {
  String get id;
  String get version;
  String get producer;
  String get schema;
  String get checksum;
  ArtifactMetadata get metadata;
  T get payload;
}

class DocumentArtifact<T> implements Artifact<T> {
  @override final String id;
  @override final String version;
  @override final String producer;
  @override final String schema;
  @override final String checksum;
  @override final ArtifactMetadata metadata;
  @override final T payload;
  DocumentArtifact({required this.id, required this.version, required this.producer, required this.schema, required this.checksum, required this.metadata, required this.payload});
}

class AstArtifact<T> implements Artifact<T> {
  @override final String id;
  @override final String version;
  @override final String producer;
  @override final String schema;
  @override final String checksum;
  @override final ArtifactMetadata metadata;
  @override final T payload;
  AstArtifact({required this.id, required this.version, required this.producer, required this.schema, required this.checksum, required this.metadata, required this.payload});
}

class ChunkArtifact<T> implements Artifact<T> {
  @override final String id;
  @override final String version;
  @override final String producer;
  @override final String schema;
  @override final String checksum;
  @override final ArtifactMetadata metadata;
  @override final T payload;
  ChunkArtifact({required this.id, required this.version, required this.producer, required this.schema, required this.checksum, required this.metadata, required this.payload});
}

class EmbeddingArtifact<T> implements Artifact<T> {
  @override final String id;
  @override final String version;
  @override final String producer;
  @override final String schema;
  @override final String checksum;
  @override final ArtifactMetadata metadata;
  @override final T payload;
  EmbeddingArtifact({required this.id, required this.version, required this.producer, required this.schema, required this.checksum, required this.metadata, required this.payload});
}

class IndexArtifact<T> implements Artifact<T> {
  @override final String id;
  @override final String version;
  @override final String producer;
  @override final String schema;
  @override final String checksum;
  @override final ArtifactMetadata metadata;
  @override final T payload;
  IndexArtifact({required this.id, required this.version, required this.producer, required this.schema, required this.checksum, required this.metadata, required this.payload});
}

class ImageArtifact<T> implements Artifact<T> {
  @override final String id;
  @override final String version;
  @override final String producer;
  @override final String schema;
  @override final String checksum;
  @override final ArtifactMetadata metadata;
  @override final T payload;
  ImageArtifact({required this.id, required this.version, required this.producer, required this.schema, required this.checksum, required this.metadata, required this.payload});
}

class AudioArtifact<T> implements Artifact<T> {
  @override final String id;
  @override final String version;
  @override final String producer;
  @override final String schema;
  @override final String checksum;
  @override final ArtifactMetadata metadata;
  @override final T payload;
  AudioArtifact({required this.id, required this.version, required this.producer, required this.schema, required this.checksum, required this.metadata, required this.payload});
}

class TensorArtifact<T> implements Artifact<T> {
  @override final String id;
  @override final String version;
  @override final String producer;
  @override final String schema;
  @override final String checksum;
  @override final ArtifactMetadata metadata;
  @override final T payload;
  TensorArtifact({required this.id, required this.version, required this.producer, required this.schema, required this.checksum, required this.metadata, required this.payload});
}

class ModelArtifact<T> implements Artifact<T> {
  @override final String id;
  @override final String version;
  @override final String producer;
  @override final String schema;
  @override final String checksum;
  @override final ArtifactMetadata metadata;
  @override final T payload;
  ModelArtifact({required this.id, required this.version, required this.producer, required this.schema, required this.checksum, required this.metadata, required this.payload});
}
