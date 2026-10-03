import 'package:feature_coins_core/src/currency/coins_amount_input.dart';
import 'package:test/test.dart';

void main() {
  group('CoinsAmountInput', () {
    test('allowedInputCharacters is not rupee-locked', () {
      expect(CoinsAmountInput.allowedInputCharacters.hasMatch('123.45'), isTrue);
      expect(CoinsAmountInput.allowedInputCharacters.hasMatch('1,234.56'), isTrue);
      expect(CoinsAmountInput.allowedInputCharacters.hasMatch('₹'), isFalse);
      expect(CoinsAmountInput.allowedInputCharacters.hasMatch('\$'), isFalse);
    });

    test('parseToCents accepts common global formats', () {
      expect(CoinsAmountInput.parseToCents('300'), 30000);
      expect(CoinsAmountInput.parseToCents('1,234.56'), 123456);
      expect(CoinsAmountInput.parseToCents('300,50'), 30050);
      expect(CoinsAmountInput.parseToCents('\$42.10'), 4210);
      expect(CoinsAmountInput.parseToCents('€99,99'), 9999);
    });
  });
}
