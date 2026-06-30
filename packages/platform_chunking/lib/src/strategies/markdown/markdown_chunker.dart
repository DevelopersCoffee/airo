
import '../../models/chunk_models.dart';
import '../chunking_strategy.dart';
import 'package:platform_content/platform_content.dart';

class MarkdownChunkStrategy implements ChunkStrategy {
  @override
  String get strategyName => 'markdown_recursive';

  @override
  Future<List<Chunk>> chunk(List<ContentNode> nodes, ChunkPolicy policy) async {
    // Reference implementation using visitor
    final chunks = <Chunk>[];
    // Normally we'd use a visitor to extract text and apply size limits
    chunks.add(Chunk(
      id: const ChunkId('chunk-1'),
      content: 'Stubbed markdown chunk',
      metadata: ChunkMetadata({}),
    ));
    return chunks;
  }
}
