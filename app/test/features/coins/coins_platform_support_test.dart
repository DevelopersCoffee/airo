import 'package:airo_app/features/coins/coins.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CoinsPlatformSupport', () {
    test('disables local-only group storage on web', () {
      expect(CoinsPlatformSupport.groupsAvailable(isWeb: true), isFalse);
      expect(CoinsPlatformSupport.groupsAvailable(isWeb: false), isTrue);
    });
  });
}
