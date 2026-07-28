import 'package:airo_pro_bootstrap/airo_pro_bootstrap.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('open-source bootstrap contributes no provider overrides', () {
    expect(createProviderOverrides(), isEmpty);
  });
}
