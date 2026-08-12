import 'package:feature_coins_core/src/models/labeled_merchant_example.dart';
import 'package:feature_coins_core/src/models/merchant_category.dart';
import 'package:feature_coins_core/src/services/embedding_knn_categorizer.dart';
import 'package:test/test.dart';

void main() {
  group('EmbeddingKnnCategorizer', () {
    const categorizer = EmbeddingKnnCategorizer();

    test('returns null with no examples', () {
      expect(categorizer.classify([1, 0, 0], const []), isNull);
    });

    test('returns null when nothing clears the similarity threshold', () {
      final examples = [
        const LabeledMerchantExample(
          merchantText: 'Netflix',
          embedding: [1, 0, 0],
          category: MerchantCategory('shopping', 'Entertainment'),
        ),
      ];

      // Orthogonal vector -- cosine similarity 0.
      expect(categorizer.classify([0, 1, 0], examples), isNull);
    });

    test('returns the closest example above threshold', () {
      final examples = [
        const LabeledMerchantExample(
          merchantText: 'Netflix',
          embedding: [1, 0, 0],
          category: MerchantCategory('shopping', 'Entertainment'),
        ),
        const LabeledMerchantExample(
          merchantText: 'Uber',
          embedding: [0, 1, 0],
          category: MerchantCategory('transport', 'Travel'),
        ),
      ];

      final result = categorizer.classify([0.9, 0.1, 0], examples);

      expect(result, const MerchantCategory('shopping', 'Entertainment'));
    });

    test('majority vote among top-k neighbors', () {
      final examples = [
        const LabeledMerchantExample(
          merchantText: 'Netflix',
          embedding: [1, 0, 0],
          category: MerchantCategory('shopping', 'Entertainment'),
        ),
        const LabeledMerchantExample(
          merchantText: 'Hulu',
          embedding: [0.95, 0.05, 0],
          category: MerchantCategory('shopping', 'Entertainment'),
        ),
        const LabeledMerchantExample(
          merchantText: 'Some Transport Co',
          embedding: [0.9, 0.1, 0.05],
          category: MerchantCategory('transport', 'Travel'),
        ),
      ];

      final result = categorizer.classify([1, 0, 0], examples);

      expect(result, const MerchantCategory('shopping', 'Entertainment'));
    });
  });
}
