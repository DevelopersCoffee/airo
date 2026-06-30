import 'package:platform_identity/platform_identity.dart';

/// Represents a model's embedding capabilities, allowing `platform_embeddings`
/// to decouple embedding logic from specific execution engines (like llama.cpp or LiteRT).
abstract class EmbeddingProvider {
  /// The unique identifier of the engine or provider powering this generation.
  EngineId get providerId;

  /// Generates a single vector embedding for the given [text].
  Future<List<double>> generateEmbedding(String text);

  /// Generates multiple vector embeddings for a batch of [texts].
  Future<List<List<double>>> generateEmbeddings(List<String> texts);
}
