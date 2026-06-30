import 'dart:typed_data';
import 'package:platform_identity/platform_identity.dart';
import 'package:platform_ast/platform_ast.dart';
import 'package:platform_content_types/platform_content_types.dart';

abstract interface class Artifact<T> {
  ArtifactId get id;
  String get version;
  String get producer;
  String get schema;
  String get checksum;
  Metadata get metadata;
  T get payload;
}

abstract class BaseArtifact<T> implements Artifact<T> {
  const BaseArtifact({
    required this.id,
    required this.version,
    required this.producer,
    required this.schema,
    required this.checksum,
    required this.metadata,
    required this.payload,
  });

  @override final ArtifactId id;
  @override final String version;
  @override final String producer;
  @override final String schema;
  @override final String checksum;
  @override final Metadata metadata;
  @override final T payload;
}

class RawArtifact extends BaseArtifact<Stream<Uint8List>> {
  const RawArtifact({required super.id, required super.version, required super.producer, required super.schema, required super.checksum, required super.metadata, required super.payload});
}

class ParsedArtifact extends BaseArtifact<Stream<AstEvent>> {
  const ParsedArtifact({required super.id, required super.version, required super.producer, required super.schema, required super.checksum, required super.metadata, required super.payload});
}

class SemanticArtifact extends BaseArtifact<AstNode> {
  const SemanticArtifact({required super.id, required super.version, required super.producer, required super.schema, required super.checksum, required super.metadata, required super.payload});
}

class NormalizedArtifact extends BaseArtifact<AstNode> {
  const NormalizedArtifact({required super.id, required super.version, required super.producer, required super.schema, required super.checksum, required super.metadata, required super.payload});
}

class ChunkArtifact extends BaseArtifact<List<String>> {
  const ChunkArtifact({required super.id, required super.version, required super.producer, required super.schema, required super.checksum, required super.metadata, required super.payload});
}

class EmbeddingArtifact extends BaseArtifact<List<List<double>>> {
  const EmbeddingArtifact({required super.id, required super.version, required super.producer, required super.schema, required super.checksum, required super.metadata, required super.payload});
}

class IndexArtifact extends BaseArtifact<String> {
  const IndexArtifact({required super.id, required super.version, required super.producer, required super.schema, required super.checksum, required super.metadata, required super.payload});
}

class RetrievalArtifact extends BaseArtifact<List<Map<String, dynamic>>> {
  const RetrievalArtifact({required super.id, required super.version, required super.producer, required super.schema, required super.checksum, required super.metadata, required super.payload});
}
