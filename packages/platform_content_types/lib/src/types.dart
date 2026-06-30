import 'dart:typed_data';
import 'package:platform_identity/platform_identity.dart';

class Metadata {
  Metadata(this.data);
  final Map<String, dynamic> data;
}

class Asset {
  Asset(this.id, this.uri, this.bytes);
  final String id;
  final String uri;
  final Uint8List bytes;
}

class ContentDocument {
  ContentDocument(this.id, this.metadata, this.assets);
  final EntityId id;
  final Metadata metadata;
  final List<Asset> assets;
}
