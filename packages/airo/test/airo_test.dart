import 'package:flutter_test/flutter_test.dart';
import 'package:airo/airo.dart';

void main() {
  group('Airo Package', () {
    test('AiroConstants has expected default values', () {
      expect(AiroConstants.packageName, 'airo');
      expect(AiroConstants.packageVersion, isNotEmpty);
      expect(AiroConstants.maxTokensPerRequest, greaterThan(0));
    });
  });
}
