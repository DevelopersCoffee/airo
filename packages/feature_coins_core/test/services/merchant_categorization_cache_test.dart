import 'package:feature_coins_core/src/models/merchant_category.dart';
import 'package:feature_coins_core/src/services/merchant_categorization_cache.dart';
import 'package:test/test.dart';

void main() {
  group('MerchantCategorizationCache', () {
    test('lookup returns null for an unseen merchant', () {
      final cache = MerchantCategorizationCache();

      expect(cache.lookup('Netflix'), isNull);
      expect(cache.contains('Netflix'), isFalse);
    });

    test('record then lookup round-trips', () {
      final cache = MerchantCategorizationCache();
      const category = MerchantCategory('shopping', 'Entertainment');

      cache.record('Netflix', category);

      expect(cache.lookup('Netflix'), category);
      expect(cache.contains('Netflix'), isTrue);
    });

    test('lookup is case- and whitespace-insensitive', () {
      final cache = MerchantCategorizationCache();
      const category = MerchantCategory('shopping', 'Entertainment');

      cache.record('  Netflix  ', category);

      expect(cache.lookup('NETFLIX'), category);
      expect(cache.lookup('netflix'), category);
    });

    test('a second record overwrites the first', () {
      final cache = MerchantCategorizationCache();
      cache.record('Netflix', const MerchantCategory('shopping', 'Shopping'));

      cache.record(
        'Netflix',
        const MerchantCategory('shopping', 'Entertainment'),
      );

      expect(
        cache.lookup('Netflix'),
        const MerchantCategory('shopping', 'Entertainment'),
      );
    });
  });
}
