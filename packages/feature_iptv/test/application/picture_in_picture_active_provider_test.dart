import 'package:feature_iptv/application/player_backgrounding_coordinator.dart';
import 'package:feature_iptv/feature_iptv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:platform_player/platform_player.dart';

// #1002: the session-scoped coordinator provider owns the single native PiP
// state-change subscription and mirrors it into
// pictureInPictureActiveProvider so any widget can switch to a video-only
// layout while the PiP window is up.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() {
    AiroNativePictureInPicture.setStateChangeHandler(null);
  });

  test('native PiP state changes mirror into pictureInPictureActiveProvider',
      () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    // Reading the provider activates the subscription.
    container.read(playerBackgroundingCoordinatorProvider);

    expect(container.read(pictureInPictureActiveProvider), isFalse);

    AiroNativePictureInPicture.debugNotifyStateChanged(true);
    expect(container.read(pictureInPictureActiveProvider), isTrue);

    AiroNativePictureInPicture.debugNotifyStateChanged(false);
    expect(container.read(pictureInPictureActiveProvider), isFalse);
  });

  test('disposing the coordinator provider clears the native handler', () {
    final container = ProviderContainer();
    container.read(playerBackgroundingCoordinatorProvider);

    container.dispose();

    // After dispose the handler is cleared, so a native state change must
    // not reach the (now disposed) provider.
    AiroNativePictureInPicture.debugNotifyStateChanged(true);
    expect(
      () => container.read(pictureInPictureActiveProvider),
      throwsStateError,
    );
  });
}
