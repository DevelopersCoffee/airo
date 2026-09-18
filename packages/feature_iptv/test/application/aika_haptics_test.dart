import 'package:fake_async/fake_async.dart';
import 'package:feature_iptv/application/aika_haptics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:platform_haptics/platform_haptics.dart';
import 'package:platform_haptics/testing.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeAiroHapticPlatform fake;
  late EngineAikaHaptics haptics;

  setUp(() async {
    fake = FakeAiroHapticPlatform();
    AiroHapticsPlatform.instance = fake;
    AiroHaptics.profile = AiroHapticProfile.defaultProfile;
    await AiroHaptics.updateSettings(
      const AiroHapticSettings(minThrottleDuration: Duration.zero),
    );
    fake.clearInvocations();
    haptics = EngineAikaHaptics();
  });

  tearDown(() async {
    await haptics.detachCastSession();
  });

  test('playPause maps to selection', () async {
    await haptics.play(AikaHapticIntent.playPause);
    expectHapticPlayed(fake, AiroHapticFeedbackType.selection);
  });

  test('channelStep maps to navigation', () async {
    await haptics.play(AikaHapticIntent.channelStep);
    expectHapticPlayed(fake, AiroHapticFeedbackType.navigation);
  });

  test('favoriteOn and favoriteOff map to toggles', () async {
    await haptics.play(AikaHapticIntent.favoriteOn);
    await haptics.play(AikaHapticIntent.favoriteOff);
    expectHapticPlayed(fake, AiroHapticFeedbackType.toggleOn);
    expectHapticPlayed(fake, AiroHapticFeedbackType.toggleOff);
  });

  test('error maps to error', () async {
    await haptics.play(AikaHapticIntent.error);
    expectHapticPlayed(fake, AiroHapticFeedbackType.error);
  });

  test('castConnected maps to success', () async {
    await haptics.play(AikaHapticIntent.castConnected);
    expectHapticPlayed(fake, AiroHapticFeedbackType.success);
  });

  test('mute maps to selection', () async {
    await haptics.play(AikaHapticIntent.mute);
    expectHapticPlayed(fake, AiroHapticFeedbackType.selection);
  });

  test('stop maps to medium impact', () async {
    await haptics.play(AikaHapticIntent.stop);
    expect(
      fake.invocations.any((i) => i.impact == AiroHapticImpact.medium),
      isTrue,
    );
  });

  test('volumeTick coalesces into selection', () {
    fakeAsync((async) {
      haptics.play(AikaHapticIntent.volumeTick);
      async.elapse(const Duration(milliseconds: 20));
      expectHapticPlayed(fake, AiroHapticFeedbackType.selection);
    });
  });

  test('unsupported hardware is a silent no-op', () async {
    fake.capabilities = const AiroHapticCapabilities.unsupported();
    await haptics.play(AikaHapticIntent.playPause);
    expectNoHapticPlayed(fake);
  });

  test('play swallows platform errors', () async {
    AiroHapticsPlatform.instance = _ThrowingHapticPlatform();
    await expectLater(haptics.play(AikaHapticIntent.playPause), completes);
  });

  test('attachCastSession is idempotent for the same id', () async {
    await haptics.attachCastSession(id: 'tv-1');
    await haptics.attachCastSession(id: 'tv-1');
    expect(haptics.castSessionId, 'tv-1');
    expect(AiroHaptics.profile, AiroHapticProfile.media);
  });

  test('detachCastSession stops playback and is safe twice', () async {
    await haptics.attachCastSession(id: 'tv-1');
    await haptics.detachCastSession();
    await haptics.detachCastSession();
    expect(haptics.castSessionId, isNull);
    expect(fake.isStopped, isTrue);
  });
}

class _ThrowingHapticPlatform extends FakeAiroHapticPlatform {
  @override
  Future<void> performFeedback(
    AiroHapticFeedbackType type, {
    AiroHapticOptions? options,
  }) async {
    throw StateError('plugin missing');
  }
}
