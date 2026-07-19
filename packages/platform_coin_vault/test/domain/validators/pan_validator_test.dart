// packages/platform_coin_vault/test/domain/validators/pan_validator_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:platform_coin_vault/src/domain/validators/pan_validator.dart';

void main() {
  group('isValidPan', () {
    test('accepts a well-formed PAN', () {
      expect(isValidPan('ABCDE1234F'), isTrue);
    });

    test('rejects wrong length', () {
      expect(isValidPan('ABCDE1234'), isFalse);
    });

    test('rejects digits in the letter positions', () {
      expect(isValidPan('12CDE1234F'), isFalse);
    });

    test('rejects lowercase', () {
      expect(isValidPan('abcde1234f'), isFalse);
    });

    test('rejects empty string', () {
      expect(isValidPan(''), isFalse);
    });
  });
}
