import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:feature_iptv/feature_iptv.dart';

// Mirrors iptv_screen_ten_foot_fullscreen_test.dart's setup, but for the
// default (touch, non-tenFootMode) screen used on phones/tablets/foldables.
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
    'touch (non-tenFootMode): exiting fullscreen restores system-default '
    'orientation instead of forcing portrait, so tablets/foldables already '
    'in landscape are not rotated out of it',
    (tester) async {
      tester.view.physicalSize = const Size(1024, 768);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final orientationCalls = <List<Object?>>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'SystemChrome.setPreferredOrientations') {
            orientationCalls.add(call.arguments as List<Object?>);
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );

      final played = <IPTVChannel>[];
      final stateController = StreamController<StreamingState>.broadcast();
      addTearDown(stateController.close);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            iptvChannelsProvider.overrideWith((ref) async => _channels),
            recentlyWatchedChannelsProvider.overrideWith(
              (ref) async => const [],
            ),
            streamingStateProvider.overrideWith(
              (ref) => stateController.stream,
            ),
            iptvStreamingServiceProvider.overrideWith((ref) {
              final service = _RecordingStreamingService(played: played);
              ref.onDispose(service.dispose);
              return service;
            }),
          ],
          child: const MaterialApp(home: IPTVScreen()),
        ),
      );
      await tester.pump();
      stateController.add(
        StreamingState(playbackState: PlaybackState.idle, isLiveStream: true),
      );
      await tester.pump();

      await tester.tap(find.text('Channel One'));
      await tester.pump(const Duration(milliseconds: 400));
      stateController.add(
        StreamingState(
          playbackState: PlaybackState.playing,
          isLiveStream: true,
          currentChannel: _channels.single,
        ),
      );
      await tester.pump(const Duration(milliseconds: 400));

      // Enter fullscreen via the preview stage's fullscreen button, then
      // exit with back/escape (bounded pumps: the fullscreen player shows
      // a looping buffering spinner, so pumpAndSettle would never settle).
      await tester.tap(
        find.byKey(const ValueKey('iptv-preview-fullscreen-button')),
      );
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump(const Duration(milliseconds: 400));

      expect(
        orientationCalls.where(
          (arguments) => arguments.contains('DeviceOrientation.portraitUp'),
        ),
        isEmpty,
        reason:
            'a phone/tablet/foldable already using landscape as its '
            'default layout must not be force-rotated to portrait on '
            'fullscreen exit',
      );
      expect(
        orientationCalls.any((arguments) => arguments.isEmpty),
        isTrue,
        reason:
            'exiting fullscreen should restore the system-default '
            'orientation (empty preference list), not force any specific '
            'orientation',
      );
    },
  );
}
