
import 'package:platform_identity/platform_identity.dart';

class ChunkId extends PlatformIdentifier {
  const ChunkId(super.value);
}

class ChunkMetadata {
  final Map<String, dynamic> attributes;
  ChunkMetadata(this.attributes);
}

class ChunkPolicy {
  final int maxTokens;
  final int overlapTokens;
  ChunkPolicy({required this.maxTokens, required this.overlapTokens});
}

class Chunk {
  final ChunkId id;
  final String content;
  final ChunkMetadata metadata;
  
  Chunk({required this.id, required this.content, required this.metadata});
}
