import 'package:feature_coins_core/src/eval/merchant_categorization_eval_harness.dart';
import 'package:feature_coins_core/src/models/merchant_category.dart';
import 'package:feature_coins_core/src/services/merchant_categorizer.dart';
import 'package:feature_coins_core/src/services/regex_merchant_categorizer.dart';
import 'package:test/test.dart';

import '../support/fake_word_bag_embedder.dart';
import 'golden/labeled_merchants_v1.dart';

void main() {
  group('MerchantCategorizationEvalHarness against labeledMerchantsV1', () {
    const harness = MerchantCategorizationEvalHarness();
    final examples = [
      for (final g in labeledMerchantsV1) MerchantEvalExample(g.text, g.expected),
    ];

    test('scorecard passes and beats the regex baseline', () {
      final categorizer = MerchantCategorizer(embedder: FakeWordBagEmbedder());
      // The one correction #1648's own tests use -- exercises the kNN
      // generalization path (Uber Eats Koramangala) the fixture includes.
      categorizer.recordCorrection(
        'Uber Eats',
        const MerchantCategory('food', 'Food'),
      );

      final scorecard = harness.run(examples, categorizer);
      final baseline = harness.baselineAccuracy(
        examples,
        const RegexMerchantCategorizer(),
      );

      expect(scorecard.sampleCount, labeledMerchantsV1.length);
      expect(scorecard.passes, isTrue);
      expect(scorecard.accuracy, greaterThanOrEqualTo(baseline));
    });

    test(
      'without any corrections, the categorizer never scores worse than '
      'the regex baseline it wraps',
      () {
        final categorizer = MerchantCategorizer(
          embedder: FakeWordBagEmbedder(),
        );

        final scorecard = harness.run(examples, categorizer);
        final baseline = harness.baselineAccuracy(
          examples,
          const RegexMerchantCategorizer(),
        );

        expect(scorecard.accuracy, greaterThanOrEqualTo(baseline));
      },
    );
  });
}
