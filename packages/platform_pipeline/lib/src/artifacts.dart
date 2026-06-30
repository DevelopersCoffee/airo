
import 'package:platform_identity/platform_identity.dart';

class ArtifactMetadata {
  final Map<String, dynamic> data;
  ArtifactMetadata([this.data = const {}]);
}

abstract interface class Artifact<T> {
  ArtifactId get id;
  String get version;
  String get producer;
  String get schema;
  String get checksum;
  ArtifactMetadata get metadata;
  T get payload;
}
