import 'package:feature_iptv/application/providers/iptv_providers.dart';
import 'package:feature_iptv/application/providers/sleep_timer_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:platform_media/src/video_player_streaming_service.dart';
import 'package:platform_player/src/services/fake_playback_engine.dart';

class _StopCounterService extends VideoPlayerStreamingService {
  _StopCounterService() : super(engine: FakeAiroPlaybackEngine());

  var stops = 0;

  @override
  Future<void> stop() async {
    stops++;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('defaults to off', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    expect(container.read(sleepTimerRemainingProvider), 0);
  });

  test('setMinutes(30) then handleTick decrements', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    container.read(sleepTimerRemainingProvider.notifier).setMinutes(30);
    expect(container.read(sleepTimerRemainingProvider), 30);
    container.read(sleepTimerRemainingProvider.notifier).handleTick();
    expect(container.read(sleepTimerRemainingProvider), 29);
  });

  test('setMinutes(15) replaces 30', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final notifier = container.read(sleepTimerRemainingProvider.notifier);
    notifier.setMinutes(30);
    notifier.setMinutes(15);
    expect(container.read(sleepTimerRemainingProvider), 15);
  });

  test('cancel zeros remaining without calling expire', () async {
    var expired = 0;
    final container = ProviderContainer(
      overrides: [
        sleepTimerExpireDelegateProvider.overrideWith(
          (ref) => () async {
            expired++;
          },
        ),
      ],
    );
    addTearDown(container.dispose);
    final notifier = container.read(sleepTimerRemainingProvider.notifier);
    notifier.setMinutes(15);
    notifier.cancel();
    expect(container.read(sleepTimerRemainingProvider), 0);
    expect(expired, 0);
  });

  test('invalid minutes cancel', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final notifier = container.read(sleepTimerRemainingProvider.notifier);
    notifier.setMinutes(30);
    notifier.setMinutes(7);
    expect(container.read(sleepTimerRemainingProvider), 0);
  });

  test('tick to zero calls expire once then stays off', () async {
    var expired = 0;
    final container = ProviderContainer(
      overrides: [
        sleepTimerExpireDelegateProvider.overrideWith(
          (ref) => () async {
            expired++;
          },
        ),
      ],
    );
    addTearDown(container.dispose);
    final notifier = container.read(sleepTimerRemainingProvider.notifier);
    notifier.setMinutes(15);
    for (var i = 0; i < 15; i++) {
      notifier.handleTick();
    }
    expect(container.read(sleepTimerRemainingProvider), 0);
    expect(expired, 1);
    notifier.handleTick();
    expect(expired, 1);
  });

  test('default expire stops playback and leaves fullscreen', () async {
    final service = _StopCounterService();
    final container = ProviderContainer(
      overrides: [iptvStreamingServiceProvider.overrideWithValue(service)],
    );
    addTearDown(container.dispose);
    container.read(isFullscreenModeProvider.notifier).state = true;
    await container.read(sleepTimerExpireDelegateProvider)();
    expect(service.stops, 1);
    expect(container.read(isFullscreenModeProvider), isFalse);
  });
}
