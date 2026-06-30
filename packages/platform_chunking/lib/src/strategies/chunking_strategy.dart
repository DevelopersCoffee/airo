
import '../models/chunk_models.dart';
import 'package:platform_content/platform_content.dart';

abstract class ChunkSelector {
  List<ContentNode> select(ContentDocument document);
}

abstract class ChunkStrategy {
  String get strategyName;
  Future<List<Chunk>> chunk(List<ContentNode> nodes, ChunkPolicy policy);
}

abstract class ChunkPostProcessor {
  Future<List<Chunk>> process(List<Chunk> chunks, ContentDocument sourceDocument);
}
