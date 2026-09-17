import 'package:flutter_test/flutter_test.dart';
import 'package:platform_haptics/platform_haptics.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('platform_haptics re-exports AiroHaptics facade successfully', () {
    expect(AiroHaptics.settings.enabled, isTrue);
  });
}
