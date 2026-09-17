import 'package:airo_haptics/airo_haptics.dart';
import 'package:airo_haptics/testing.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeAiroHapticPlatform fakePlatform;

  setUp(() async {
    fakePlatform = FakeAiroHapticPlatform();
    AiroHapticsPlatform.instance = fakePlatform;
    await AiroHaptics.updateSettings(const AiroHapticSettings());
    AiroHaptics.theme = AiroHapticTheme.standard();
    fakePlatform.clearInvocations();
  });

  group('AiroHaptics Facade', () {
    test('semantic shortcuts invoke platform performFeedback', () async {
      await AiroHaptics.success();
      await AiroHaptics.warning();
      await AiroHaptics.error();
      await AiroHaptics.delete();

      expect(fakePlatform.invocations.length, 4);
      expect(fakePlatform.invocations[0].feedbackType, AiroHapticFeedbackType.success);
      expect(fakePlatform.invocations[1].feedbackType, AiroHapticFeedbackType.warning);
      expect(fakePlatform.invocations[2].feedbackType, AiroHapticFeedbackType.error);
      expect(fakePlatform.invocations[3].feedbackType, AiroHapticFeedbackType.delete);
    });

    test('impact shortcuts invoke platform performImpact with correct intensity', () async {
      await AiroHaptics.lightImpact();
      await AiroHaptics.heavyImpact();

      expect(fakePlatform.invocations.length, 2);
      expect(fakePlatform.invocations[0].impact, AiroHapticImpact.light);
      expect(fakePlatform.invocations[1].impact, AiroHapticImpact.heavy);
      expect(fakePlatform.invocations[1].intensity, 1.0);
    });

    test('pattern playback invokes playPattern', () async {
      final pattern = AiroHapticPattern.doubleClick();
      await AiroHaptics.playPattern(pattern);

      expect(fakePlatform.invocations.length, 1);
      expect(fakePlatform.invocations[0].method, 'playPattern');
      expect(fakePlatform.invocations[0].pattern, pattern);
    });

    test('stopAll triggers platform stopAll', () async {
      await AiroHaptics.stopAll();
      expect(fakePlatform.isStopped, isTrue);
    });

    test('expressive theme overrides semantic feedback with pattern', () async {
      AiroHaptics.theme = AiroHapticTheme.expressive();
      await AiroHaptics.success();

      expect(fakePlatform.invocations.length, 1);
      expect(fakePlatform.invocations[0].method, 'playPattern');
      expect(fakePlatform.invocations[0].pattern?.id, 'preset_success_wave');
    });

    test('global settings toggle respects disabled state', () async {
      await AiroHaptics.updateSettings(const AiroHapticSettings(enabled: false));
      fakePlatform.clearInvocations();
      await AiroHaptics.success();

      expect(fakePlatform.invocations.isEmpty, isTrue);
    });

    test('UI interaction coalesced helpers trigger feedback', () async {
      AiroHaptics.sliderStep();
      await Future<void>.delayed(const Duration(milliseconds: 30));

      expect(fakePlatform.invocations.length, 1);
      expect(fakePlatform.invocations.first.feedbackType, AiroHapticFeedbackType.selection);
    });
  });
}
