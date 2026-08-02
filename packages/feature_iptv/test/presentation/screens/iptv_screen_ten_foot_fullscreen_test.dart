import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
  testWidgets('tenFootMode: Ways to Watch excludes Cast to another TV', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(960, 540);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final played = <IPTVChannel>[];
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          iptvChannelsProvider.overrideWith((ref) async => _channels),
          recentlyWatchedChannelsProvider.overrideWith((ref) async => const []),
          streamingStateProvider.overrideWith(
            (ref) => Stream.value(
              StreamingState(
                playbackState: PlaybackState.playing,
                currentChannel: _channels.single,
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
        child: const MaterialApp(home: IPTVScreen(tenFootMode: true)),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('channel-info-ways-to-watch')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('ways-to-watch-dialog')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('ways-to-watch-cast')),
      findsNothing,
      reason:
          'a remote-only Android TV or Fire TV should not offer to cast '
          'its playback to another television',
    );
  });

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
      expect(
        tester
            .widget<VideoPlayerWidget>(find.byType(VideoPlayerWidget))
            .showPictureInPicture,
        isFalse,
        reason:
            'Android TV and Fire TV use a remote-only player where '
            'Picture-in-Picture is not a meaningful action',
      );

      // Fire OS dispatches BACK as both a raw GoBack key and a platform
      // pop-route request. The first event must not exit fullscreen and
      // expose the route to the second event, which would close the app.
      final fullscreenFocus = tester.widget<Focus>(
        find.byWidgetPredicate(
          (widget) =>
              widget is Focus &&
              widget.focusNode?.debugLabel == 'IPTV fullscreen back handler',
        ),
      );
      final rawBackResult = fullscreenFocus.onKeyEvent!.call(
        fullscreenFocus.focusNode!,
        const KeyDownEvent(
          physicalKey: PhysicalKeyboardKey.escape,
          logicalKey: LogicalKeyboardKey.goBack,
          timeStamp: Duration.zero,
        ),
      );
      await tester.pump();
      expect(rawBackResult, KeyEventResult.ignored);
      expect(container.read(isFullscreenModeProvider), isTrue);

      final handled = await tester.binding.handlePopRoute();
      await tester.pump(const Duration(milliseconds: 400));
      expect(handled, isTrue);
      expect(
        container.read(isFullscreenModeProvider),
        isTrue,
        reason:
            'the platform half of Fire OS BACK must not independently exit '
            'fullscreen after the player handled the raw half',
      );

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump(const Duration(milliseconds: 400));
      expect(container.read(isFullscreenModeProvider), isFalse);
      expect(find.byKey(const ValueKey('iptv-browse-grid')), findsOneWidget);

      final immediateDuplicateHandled = await tester.binding.handlePopRoute();
      await tester.pump();
      expect(immediateDuplicateHandled, isTrue);
      expect(find.byKey(const ValueKey('iptv-browse-grid')), findsOneWidget);

      // AFTSSS can repeat the platform half after the old one-second guard
      // elapsed, and can dispatch it more than once. Keep the browse route
      // guarded until the next deliberate raw BACK begins a new operation.
      await tester.pump(const Duration(seconds: 6));
      for (var duplicate = 0; duplicate < 2; duplicate++) {
        final duplicateHandled = await tester.binding.handlePopRoute();
        await tester.pump();
        expect(duplicateHandled, isTrue);
        expect(
          find.byKey(const ValueKey('iptv-browse-grid')),
          findsOneWidget,
          reason: 'a delayed duplicate Fire OS BACK must not close the app',
        );
      }
    },
  );

  testWidgets(
    'tenFootMode: exiting fullscreen never rotates the TV to portrait',
    (tester) async {
      tester.view.physicalSize = const Size(960, 540);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      // Record every SystemChrome.setPreferredOrientations call.
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
          child: const MaterialApp(home: IPTVScreen(tenFootMode: true)),
        ),
      );
      await tester.pumpAndSettle();

      // Enter fullscreen by selecting a channel, then exit with back.
      // Bounded pumps: the fullscreen player shows a looping buffering
      // spinner, so pumpAndSettle would never settle.
      await tester.tap(find.text('Channel One'));
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
            'a television must never be asked to rotate to portrait — '
            'seen on Fire TV Stick: display flipped to 1080x1920 after '
            'exiting the full player',
      );
    },
  );

  testWidgets(
    'tenFootMode: the D-pad still reaches the player after rebuilds while '
    'fullscreen (regression: an outer focus node re-requested focus on '
    'every build, permanently stealing it back from the player once live '
    'playback started rebuilding for buffering/position updates)',
    (tester) async {
      tester.view.physicalSize = const Size(960, 540);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

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
          child: const MaterialApp(home: IPTVScreen(tenFootMode: true)),
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

      // The player only organically claims focus from the outer Back-only
      // node once its own controls-auto-hide timer fires and calls
      // requestFocus() (VideoPlayerWidget._controlsHideDelay = 4s) -- so
      // clear that first, same as real playback would.
      await tester.pump(const Duration(seconds: 5));

      // Now simulate the rebuilds live playback drives constantly once a
      // channel is playing (buffering/position/quality updates) -- exactly
      // what used to let the outer Back-only focus node re-request and
      // steal focus back from the player on every single one of them.
      for (var i = 0; i < 5; i++) {
        stateController.add(
          StreamingState(
            playbackState: PlaybackState.playing,
            isLiveStream: true,
            currentChannel: _channels.single,
            position: Duration(seconds: i),
          ),
        );
        await tester.pump(const Duration(milliseconds: 50));
      }

      expect(
        find.text('Channel One'),
        findsWidgets,
        reason:
            'sanity check: the streamed state must have actually '
            'propagated before testing the key event',
      );

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.pump();

      expect(
        find.text('Mini guide'),
        findsOneWidget,
        reason:
            'Up must still reach the player\'s TvInputHandler after '
            'several rebuilds, not just on the first frame of fullscreen',
      );
    },
  );
}
