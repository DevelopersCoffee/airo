import 'package:feature_coins_core/src/models/merchant_category.dart';
import 'package:feature_coins_core/src/services/merchant_categorizer.dart';
import 'package:feature_coins_core/src/services/regex_merchant_categorizer.dart';
import 'package:test/test.dart';

import '../support/fake_word_bag_embedder.dart';

void main() {
  group('MerchantCategorizer consistency invariant', () {
    test('the same merchant always resolves to the same category', () {
      final categorizer = MerchantCategorizer(embedder: FakeWordBagEmbedder());

      final first = categorizer.categorize('Pizza Hut');
      final second = categorizer.categorize('Pizza Hut');
      final third = categorizer.categorize('Pizza Hut');

      expect(second, first);
      expect(third, first);
    });

    test('a later correction to a different merchant does not disturb '
        'an already-decided one', () {
      final categorizer = MerchantCategorizer(embedder: FakeWordBagEmbedder());

      final decided = categorizer.categorize('Pizza Hut');
      categorizer.recordCorrection(
        'Random New Place',
        const MerchantCategory('shopping', 'Shopping'),
      );

      expect(categorizer.categorize('Pizza Hut'), decided);
    });

    test('merchant matching is case- and whitespace-insensitive', () {
      final categorizer = MerchantCategorizer(embedder: FakeWordBagEmbedder());
      categorizer.recordCorrection(
        'Netflix',
        const MerchantCategory('shopping', 'Entertainment'),
      );

      expect(
        categorizer.categorize('  NETFLIX  '),
        const MerchantCategory('shopping', 'Entertainment'),
      );
    });
  });

  group('MerchantCategorizer correction loop', () {
    test('an explicit correction overrides the fallback immediately', () {
      final categorizer = MerchantCategorizer(embedder: FakeWordBagEmbedder());

      // Regex baseline would call this "transport" (matches "uber"), but
      // it's a food delivery merchant.
      expect(
        const RegexMerchantCategorizer().categorize('Uber Eats'),
        const MerchantCategory('transport', 'Travel'),
      );

      categorizer.recordCorrection(
        'Uber Eats',
        const MerchantCategory('food', 'Food'),
      );

      expect(
        categorizer.categorize('Uber Eats'),
        const MerchantCategory('food', 'Food'),
      );
    });

    test(
      'a correction generalizes to a near-duplicate merchant via kNN',
      () {
        final categorizer = MerchantCategorizer(
          embedder: FakeWordBagEmbedder(),
        );
        categorizer.recordCorrection(
          'Uber Eats',
          const MerchantCategory('food', 'Food'),
        );

        // Never explicitly corrected, but shares both words with the
        // corrected example -- the kNN path should place it in "food",
        // not fall through to the regex baseline's "transport".
        final result = categorizer.categorize('Uber Eats Koramangala');

        expect(result, const MerchantCategory('food', 'Food'));
      },
    );
  });

  group('MerchantCategorizer vs RegexMerchantCategorizer baseline', () {
    test('accuracy is at least as good as the regex baseline on a labeled '
        'sample with one correction applied', () {
      const truth = {
        'Uber Eats': MerchantCategory('food', 'Food'),
        'Uber Eats Koramangala': MerchantCategory('food', 'Food'),
        'Ola Cabs': MerchantCategory('transport', 'Travel'),
        'Swiggy Instamart': MerchantCategory('food', 'Food'),
        'AMZN Mktp IN': MerchantCategory('shopping', 'Shopping'),
      };

      final regex = const RegexMerchantCategorizer();
      var regexCorrect = 0;
      for (final entry in truth.entries) {
        if (regex.categorize(entry.key) == entry.value) regexCorrect++;
      }

      final categorizer = MerchantCategorizer(embedder: FakeWordBagEmbedder());
      categorizer.recordCorrection('Uber Eats', truth['Uber Eats']!);
      var categorizerCorrect = 0;
      for (final entry in truth.entries) {
        if (categorizer.categorize(entry.key) == entry.value) {
          categorizerCorrect++;
        }
      }

      expect(categorizerCorrect, greaterThanOrEqualTo(regexCorrect));
      // Demonstrates real improvement, not a tie -- the regex baseline
      // misclassifies both Uber Eats entries as transport.
      expect(categorizerCorrect, truth.length);
      expect(regexCorrect, lessThan(truth.length));
    });
  });
}
