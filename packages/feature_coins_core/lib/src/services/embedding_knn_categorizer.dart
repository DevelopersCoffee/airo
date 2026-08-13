import 'dart:math';

import '../models/labeled_merchant_example.dart';
import '../models/merchant_category.dart';

/// k-nearest-neighbors classifier over pre-embedded, user-corrected
/// examples. Cosine similarity, majority vote among the top [k] neighbors
/// that clear [minSimilarity]. Returns null (not a guess) when there are no
/// examples, or none are close enough -- the caller falls back to
/// [RegexMerchantCategorizer] rather than accept a low-confidence vote.
class EmbeddingKnnCategorizer {
  const EmbeddingKnnCategorizer({this.k = 3, this.minSimilarity = 0.5});

  final int k;
  final double minSimilarity;

  MerchantCategory? classify(
    List<double> queryEmbedding,
    List<LabeledMerchantExample> examples,
  ) {
    if (examples.isEmpty) return null;

    final scored =
        examples
            .map(
              (e) => (
                _cosineSimilarity(queryEmbedding, e.embedding),
                e.category,
              ),
            )
            .where((scored) => scored.$1 >= minSimilarity)
            .toList()
          ..sort((a, b) => b.$1.compareTo(a.$1));

    if (scored.isEmpty) return null;

    final top = scored.take(k);
    final votes = <String, int>{};
    final categoryById = <String, MerchantCategory>{};
    for (final (_, category) in top) {
      votes[category.categoryId] = (votes[category.categoryId] ?? 0) + 1;
      categoryById[category.categoryId] = category;
    }

    final winnerId = votes.entries
        .reduce((a, b) => b.value > a.value ? b : a)
        .key;
    return categoryById[winnerId];
  }

  double _cosineSimilarity(List<double> a, List<double> b) {
    var dot = 0.0;
    var normA = 0.0;
    var normB = 0.0;
    for (var i = 0; i < a.length; i++) {
      dot += a[i] * b[i];
      normA += a[i] * a[i];
      normB += b[i] * b[i];
    }
    if (normA == 0 || normB == 0) return 0.0;
    return dot / (sqrt(normA) * sqrt(normB));
  }
}
