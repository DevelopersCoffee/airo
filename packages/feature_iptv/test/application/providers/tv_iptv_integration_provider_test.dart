import 'package:feature_iptv/feature_iptv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeMediaSessionDelegate implements StreamingMediaSessionDelegate {
  @override
  Future<void> onChannelStarted({
    required String channelName,
    required String streamUrl,
  }) async {}

  @override
  Future<void> onPlaybackPaused() async {}

  @override
  Future<void> onPlaybackResumed() async {}

  @override
  Future<void> onPlaybackStopped() async {}
}

void main() {
  late VideoPlayerStreamingService service;

  ProviderContainer buildContainer({StreamingMediaSessionDelegate? delegate}) {
    return ProviderContainer(
      overrides: [
        iptvStreamingServiceProvider.overrideWithValue(service),
        if (delegate != null)
          tvMediaSessionDelegateProvider.overrideWithValue(delegate),
      ],
    );
  }

  setUp(() {
    service = VideoPlayerStreamingService(engine: FakeAiroPlaybackEngine());
  });

  tearDown(() async {
    await service.dispose();
  });

  group('tvIptvIntegrationProvider', () {
    test('leaves the service delegate null when the host supplies none', () {
      final container = buildContainer();
      addTearDown(container.dispose);

      container.read(tvIptvIntegrationProvider);

      expect(service.mediaSessionDelegate, isNull);
    });

    test('attaches the host-provided delegate to the shared service', () {
      final delegate = _FakeMediaSessionDelegate();
      final container = buildContainer(delegate: delegate);
      addTearDown(container.dispose);

      container.read(tvIptvIntegrationProvider);

      expect(service.mediaSessionDelegate, same(delegate));
    });

    test('a delegate change re-attaches without rebuilding the service', () {
      final first = _FakeMediaSessionDelegate();
      final second = _FakeMediaSessionDelegate();
      final container = buildContainer(delegate: first);
      addTearDown(container.dispose);

      container.read(tvIptvIntegrationProvider);
      expect(service.mediaSessionDelegate, same(first));

      // Rebuild the container with a different delegate: the streaming
      // service instance must survive (overrideWithValue) and simply get
      // re-pointed at the new delegate — no playback teardown.
      final updated = ProviderContainer(
        overrides: [
          iptvStreamingServiceProvider.overrideWithValue(service),
          tvMediaSessionDelegateProvider.overrideWithValue(second),
        ],
      );
      addTearDown(updated.dispose);

      updated.read(tvIptvIntegrationProvider);

      expect(service.mediaSessionDelegate, same(second));
      expect(updated.read(iptvStreamingServiceProvider), same(service));
    });
  });
}
