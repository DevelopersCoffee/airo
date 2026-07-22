import 'package:airo_pro_bootstrap/airo_pro_bootstrap.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('open-source pro bootstrap initializes no modules', () async {
    final initialized = await initializeProModules();

    expect(initialized, isEmpty);
  });
}
