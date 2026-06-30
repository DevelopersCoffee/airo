
import 'package:platform_identity/platform_identity.dart';

class ChunkId extends PlatformIdentifier {
  const ChunkId(super.value);
}

class ChunkMetadata {
  ChunkMetadata(this.attributes);
  final Map<String, dynamic> attributes;
}

class ChunkPolicy {
  ChunkPolicy({required this.maxTokens, required this.overlapTokens});
  final int maxTokens;
  final int overlapTokens;
}

class Chunk {
  
  Chunk({required this.id, required this.content, required this.metadata});
  final ChunkId id;
  final String content;
  final ChunkMetadata metadata;
}
