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
    AiroHaptics.profile = AiroHapticProfile.defaultProfile;
    fakePlatform.clearInvocations();
  });

  group('AiroHaptics Facade & Engine', () {
    test('semantic shortcuts invoke platform performFeedback and assertion helper matches', () async {
      await AiroHaptics.success();
      await AiroHaptics.warning();
      await AiroHaptics.error();

      expectHapticPlayed(fakePlatform, AiroHapticFeedbackType.success);
      expectHapticPlayed(fakePlatform, AiroHapticFeedbackType.warning);
      expectHapticPlayed(fakePlatform, AiroHapticFeedbackType.error);
    });

    test('impact shortcuts invoke platform performImpact with correct intensity', () async {
      await AiroHaptics.lightImpact();
      await AiroHaptics.heavyImpact();

      expect(fakePlatform.invocations.length, 2);
      expect(fakePlatform.invocations[0].impact, AiroHapticImpact.light);
      expect(fakePlatform.invocations[1].impact, AiroHapticImpact.heavy);
      expect(fakePlatform.invocations[1].intensity, 1.0);
    });

    test('controllable player lifecycle and live parameter updates', () async {
      final player = await AiroHaptics.createPlayer(AiroHapticPattern.doubleClick());
      await player.start();
      expect(player.isPlaying, isTrue);

      await player.update(intensity: 0.8, sharpness: 0.3);
      expect(player.currentIntensity, 0.8);
      expect(player.currentSharpness, 0.3);

      final updateInvocations = fakePlatform.invocations.where((i) => i.method == 'updatePattern');
      expect(updateInvocations.isNotEmpty, isTrue);

      player.stop();
      expect(player.isPlaying, isFalse);
    });

    test('isolated session lifecycle management', () async {
      final session = await AiroHaptics.startSession(id: 'test_session');
      expect(session.isActive, isTrue);

      final player = await session.play(AiroHapticPattern.doubleClick());
      expect(player, isNotNull);
      expect(session.activePlayer, isNotNull);

      await session.stop();
      expect(session.activePlayer, isNull);

      session.dispose();
      expect(session.isActive, isFalse);
    });

    test('ADSR envelope continuous haptics playback', () async {
      const envelope = AiroHapticEnvelope(
        attack: Duration(milliseconds: 20),
        decay: Duration(milliseconds: 50),
        sustain: 0.7,
        release: Duration(milliseconds: 100),
      );

      final player = await AiroHaptics.playContinuous(
        intensity: 0.6,
        sharpness: 0.4,
        envelope: envelope,
      );

      expect(player.isPlaying, isTrue);
      player.stop();
    });

    test('AHAP design format map parsing', () {
      final ahapJson = {
        'Pattern': [
          {
            'Event': {
              'EventType': 'HapticTransient',
              'Time': 0.05,
              'EventParameters': [
                {'ParameterID': 'HapticIntensity', 'ParameterValue': 0.7},
                {'ParameterID': 'HapticSharpness', 'ParameterValue': 0.8}
              ]
            }
          },
          {
            'Event': {
              'EventType': 'HapticContinuous',
              'Time': 0.2,
              'EventDuration': 0.4,
              'EventParameters': [
                {'ParameterID': 'HapticIntensity', 'ParameterValue': 0.5}
              ]
            }
          }
        ]
      };

      final pattern = AiroHapticPattern.fromAhap(ahapJson, id: 'parsed_ahap');
      expect(pattern.id, 'parsed_ahap');
      expect(pattern.events.length, 2);
      expect(pattern.events[0].type, AiroHapticEventType.transient);
      expect(pattern.events[0].intensity, 0.7);
      expect(pattern.events[1].type, AiroHapticEventType.continuous);
      expect(pattern.events[1].duration.inMilliseconds, 400);
    });

    test('profile selector updates global scaling and throttle windows', () {
      AiroHaptics.profile = AiroHapticProfile.tv;
      expect(AiroHaptics.profile, AiroHapticProfile.tv);
      expect(AiroHaptics.settings.globalScale, 0.8);
      expect(AiroHaptics.settings.minThrottleDuration, const Duration(milliseconds: 40));
    });

    test('expectNoHapticPlayed passes when no events fired', () {
      expectNoHapticPlayed(fakePlatform);
    });

    test('stopAll triggers platform stopAll', () async {
      await AiroHaptics.stopAll();
      expect(fakePlatform.isStopped, isTrue);
    });
  });
}
