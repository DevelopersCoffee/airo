import 'package:airo_haptics/airo_haptics.dart';
import 'package:airo_haptics/src/platform/airo_haptics_web.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AiroHapticsWeb webPlatform;

  setUp(() {
    webPlatform = AiroHapticsWeb();
  });

  group('AiroHapticsWeb', () {
    test('getCapabilities returns unsupported when navigator is absent in test environment', () async {
      final caps = await webPlatform.getCapabilities();
      expect(caps.platform, AiroHapticDevicePlatform.web);
      expect(caps.backend, startsWith('web_vibration_api'));
    });

    test('performFeedback executes without throwing exceptions', () async {
      expect(
        () async => webPlatform.performFeedback(AiroHapticFeedbackType.success),
        returnsNormally,
      );
    });

    test('performImpact executes without throwing exceptions', () async {
      expect(
        () async => webPlatform.performImpact(AiroHapticImpact.heavy, intensity: 0.8),
        returnsNormally,
      );
    });

    test('playPattern executes without throwing exceptions', () async {
      final pattern = AiroHapticPattern.doubleClick();
      expect(
        () async => webPlatform.playPattern(pattern),
        returnsNormally,
      );
    });

    test('stopAll executes without throwing exceptions', () async {
      expect(
        () async => webPlatform.stopAll(),
        returnsNormally,
      );
    });

    test('getDiagnostics returns valid web diagnostics', () async {
      final diag = await webPlatform.getDiagnostics();
      expect(diag.activeBackend, startsWith('web_vibration_api'));
    });
  });
}
