import 'package:fake_async/fake_async.dart';
import 'package:feature_iptv/application/aika_haptics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:platform_haptics/platform_haptics.dart';
import 'package:platform_haptics/testing.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeAiroHapticPlatform fake;
  late EngineAikaHaptics haptics;
  var now = DateTime.utc(2026, 9, 19);

  setUp(() async {
    fake = FakeAiroHapticPlatform();
    AiroHapticsPlatform.instance = fake;
    AiroHaptics.profile = AiroHapticProfile.defaultProfile;
    await AiroHaptics.updateSettings(
      const AiroHapticSettings(minThrottleDuration: Duration.zero),
    );
    fake.clearInvocations();
    now = DateTime.utc(2026, 9, 19);
    haptics = EngineAikaHaptics(clock: () => now);
  });

  tearDown(() async {
    await haptics.detachCastSession();
    await haptics.detachLocalPlayback();
  });

  test('constructing the mapper does not set the media profile', () {
    expect(AiroHaptics.profile, AiroHapticProfile.defaultProfile);
    expect(haptics.localPlaybackAttached, isFalse);
  });

  test('playPause maps to confirm', () async {
    await haptics.play(AikaHapticIntent.playPause);
    expectHapticPlayed(fake, AiroHapticFeedbackType.confirm);
  });

  test('goLive maps to confirm', () async {
    await haptics.play(AikaHapticIntent.goLive);
    expectHapticPlayed(fake, AiroHapticFeedbackType.confirm);
  });

  test('fullscreen maps to confirm', () async {
    await haptics.play(AikaHapticIntent.fullscreen);
    expectHapticPlayed(fake, AiroHapticFeedbackType.confirm);
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

  test('muteOn and muteOff map to toggles', () async {
    await haptics.play(AikaHapticIntent.muteOn);
    await haptics.play(AikaHapticIntent.muteOff);
    expectHapticPlayed(fake, AiroHapticFeedbackType.toggleOn);
    expectHapticPlayed(fake, AiroHapticFeedbackType.toggleOff);
  });

  test('error maps to error', () async {
    await haptics.play(AikaHapticIntent.error);
    expectHapticPlayed(fake, AiroHapticFeedbackType.error);
  });

  test('error cooldown is 2s wall-clock, not per signature', () async {
    await haptics.play(AikaHapticIntent.error);
    await haptics.play(AikaHapticIntent.error);
    expect(
      fake.invocations
          .where((i) => i.feedbackType == AiroHapticFeedbackType.error)
          .length,
      1,
    );

    now = now.add(const Duration(seconds: 2));
    await haptics.play(AikaHapticIntent.error);
    expect(
      fake.invocations
          .where((i) => i.feedbackType == AiroHapticFeedbackType.error)
          .length,
      2,
    );
  });

  test('castConnected maps to success', () async {
    await haptics.play(AikaHapticIntent.castConnected);
    expectHapticPlayed(fake, AiroHapticFeedbackType.success);
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

  test('attachLocalPlayback sets media and detach restores default', () async {
    await haptics.attachLocalPlayback();
    expect(haptics.localPlaybackAttached, isTrue);
    expect(AiroHaptics.profile, AiroHapticProfile.media);

    await haptics.play(AikaHapticIntent.playPause);
    expect(AiroHaptics.profile, AiroHapticProfile.media);

    await haptics.detachLocalPlayback();
    expect(haptics.localPlaybackAttached, isFalse);
    expect(AiroHaptics.profile, AiroHapticProfile.defaultProfile);
  });

  test('attachCastSession is idempotent for the same id', () async {
    await haptics.attachCastSession(id: 'tv-1');
    await haptics.attachCastSession(id: 'tv-1');
    expect(haptics.castSessionId, 'tv-1');
    expect(AiroHaptics.profile, AiroHapticProfile.media);
  });

  test(
    'detachCastSession restores default when local is not attached',
    () async {
      await haptics.attachCastSession(id: 'tv-1');
      await haptics.detachCastSession();
      await haptics.detachCastSession();
      expect(haptics.castSessionId, isNull);
      expect(fake.isStopped, isTrue);
      expect(AiroHaptics.profile, AiroHapticProfile.defaultProfile);
    },
  );

  test('Cast owns profile while a session id is set', () async {
    await haptics.attachLocalPlayback();
    await haptics.attachCastSession(id: 'tv-1');
    await haptics.detachLocalPlayback();
    expect(AiroHaptics.profile, AiroHapticProfile.media);

    await haptics.detachCastSession();
    expect(AiroHaptics.profile, AiroHapticProfile.defaultProfile);
  });

  test(
    'detach Cast keeps media while local playback is still attached',
    () async {
      await haptics.attachLocalPlayback();
      await haptics.attachCastSession(id: 'tv-1');
      await haptics.detachCastSession();
      expect(AiroHaptics.profile, AiroHapticProfile.media);
    },
  );
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
