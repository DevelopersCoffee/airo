
import '../models/chunk_models.dart';
import 'package:platform_content/platform_content.dart';

abstract class ChunkingStrategy {
  String get strategyName;
  Future<List<Chunk>> chunk(ContentDocument document, ChunkPolicy policy);
}
