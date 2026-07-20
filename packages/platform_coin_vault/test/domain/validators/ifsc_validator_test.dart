// packages/platform_coin_vault/test/domain/validators/ifsc_validator_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:platform_coin_vault/src/domain/validators/ifsc_validator.dart';

void main() {
  group('isValidIfsc', () {
    test('accepts a well-formed IFSC code', () {
      expect(isValidIfsc('HDFC0001234'), isTrue);
    });

    test('rejects wrong length', () {
      expect(isValidIfsc('HDFC001234'), isFalse);
    });

    test('rejects missing zero at position 5', () {
      expect(isValidIfsc('HDFC1001234'), isFalse);
    });

    test('rejects lowercase', () {
      expect(isValidIfsc('hdfc0001234'), isFalse);
    });

    test('rejects empty string', () {
      expect(isValidIfsc(''), isFalse);
    });
  });
}
