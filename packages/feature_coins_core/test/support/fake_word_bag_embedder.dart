import 'package:feature_coins_core/src/services/merchant_embedder.dart';

/// Deterministic test double: a hashed bag-of-words vector. Two merchant
/// strings sharing words score high cosine similarity; strings sharing
/// nothing score ~0. Stands in for the real on-device embedding model
/// (`EmbeddingService`, wired in the app layer) without needing one loaded
/// in a pure-Dart package test.
class FakeWordBagEmbedder implements MerchantEmbedder {
  static const _dimensions = 256;

  @override
  List<double> embed(String text) {
    final vector = List<double>.filled(_dimensions, 0.0);
    final words = text
        .toLowerCase()
        .split(RegExp('[^a-z0-9]+'))
        .where((w) => w.isNotEmpty);
    for (final word in words) {
      final index = word.hashCode.abs() % _dimensions;
      vector[index] += 1.0;
    }
    return vector;
  }
}
