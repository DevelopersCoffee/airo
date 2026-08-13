/// Turns a merchant/transaction description into a fixed-length embedding
/// vector. Deliberately an interface, not a concrete on-device model: this
/// package is pure Dart and cannot depend on `core_ai`'s Mind embedding
/// runtime (a Flutter/platform-channel dependency). The real production
/// implementation wires this to `EmbeddingService` (the same one Mind's
/// semantic search uses); tests and eval harnesses use a deterministic
/// fake. See COINS-AI-5 scope note: "embeddings path can land first".
abstract class MerchantEmbedder {
  List<double> embed(String text);
}
