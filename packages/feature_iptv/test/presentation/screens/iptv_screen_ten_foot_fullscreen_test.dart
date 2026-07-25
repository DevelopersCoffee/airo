import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:feature_iptv/feature_iptv.dart';

// Mirrors iptv_screen_default_to_live_test.dart's setup: overrides the
// channel/recent/streaming providers directly so the screen builds without
// touching real SharedPreferences or a real playback engine.
final _channels = [
  const IPTVChannel(
    id: 'c1',
    name: 'Channel One',
    streamUrl: 'https://example.com/c1.m3u8',
    group: 'News',
    category: ChannelCategory.news,
  ),
];

class _RecordingStreamingService extends VideoPlayerStreamingService {
  _RecordingStreamingService({required this.played})
    : super(engine: FakeAiroPlaybackEngine());

  final List<IPTVChannel> played;

  @override
  Future<void> playChannel(IPTVChannel channel) async {
    played.add(channel);
  }
}

void main() {
  testWidgets(
    'tenFootMode: selecting a channel goes straight to fullscreen playback',
    (tester) async {
      tester.view.physicalSize = const Size(960, 540);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final played = <IPTVChannel>[];
      late final ProviderContainer container;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            iptvChannelsProvider.overrideWith((ref) async => _channels),
            recentlyWatchedChannelsProvider.overrideWith(
              (ref) async => const [],
            ),
            streamingStateProvider.overrideWith(
              (ref) => Stream.value(
                StreamingState(
                  playbackState: PlaybackState.idle,
                  isLiveStream: true,
                ),
              ),
            ),
            iptvStreamingServiceProvider.overrideWith((ref) {
              final service = _RecordingStreamingService(played: played);
              ref.onDispose(service.dispose);
              return service;
            }),
          ],
          child: Builder(
            builder: (context) {
              container = ProviderScope.containerOf(context);
              return const MaterialApp(home: IPTVScreen(tenFootMode: true));
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(container.read(isFullscreenModeProvider), isFalse);

      // Select the channel row in the shell's channel table.
      await tester.tap(find.text('Channel One'));
      await tester.pump();

      expect(played.map((channel) => channel.id), ['c1']);
      expect(
        container.read(isFullscreenModeProvider),
        isTrue,
        reason:
            'on TV, choosing a channel should open the full player '
            'directly instead of the small preview stage',
      );
    },
  );
}
