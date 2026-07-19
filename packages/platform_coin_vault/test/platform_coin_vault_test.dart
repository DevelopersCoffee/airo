import 'package:flutter_test/flutter_test.dart';
import 'package:platform_coin_vault/platform_coin_vault.dart';

void main() {
  test('package resolves and exports its public API', () {
    expect(isValidIfsc('HDFC0001234'), isTrue);
  });
}
