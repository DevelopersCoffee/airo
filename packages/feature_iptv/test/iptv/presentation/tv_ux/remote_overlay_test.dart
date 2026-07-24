import 'package:feature_iptv/presentation/tv_ux/sections/remote_overlay.dart';
import 'package:flutter/material.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:platform_channels/platform_channels.dart';

void main() {
  const channels = [
    IPTVChannel(id: 'one', name: 'One', streamUrl: 'https://one'),
    IPTVChannel(id: 'two', name: 'Two', streamUrl: 'https://two'),
  ];

  test('random channel selects only from the supplied filtered channels', () {
    final selected = randomFilteredChannel(channels, nextInt: (_) => 1);

    expect(selected, channels.last);
  });

  test('random channel handles empty and one-item filtered lists', () {
    expect(randomFilteredChannel(const [], nextInt: (_) => 0), isNull);
    expect(
      randomFilteredChannel([channels.first], nextInt: (_) => 0),
      channels.first,
    );
  });

  testWidgets('touch controls dispatch, hide, and reappear on pointer input', (
    tester,
  ) async {
    var volumeDown = 0;
    var volumeUp = 0;
    var previous = 0;
    var next = 0;
    var mute = 0;
    var random = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RemoteOverlay(
            autoHideDuration: const Duration(seconds: 1),
            onVolumeDown: () => volumeDown++,
            onVolumeUp: () => volumeUp++,
            onChannelPrevious: () => previous++,
            onChannelNext: () => next++,
            onMute: () => mute++,
            onRandom: () => random++,
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('remote-volume-down')));
    await tester.tap(find.byKey(const ValueKey('remote-volume-up')));
    await tester.tap(find.byKey(const ValueKey('remote-channel-previous')));
    await tester.tap(find.byKey(const ValueKey('remote-channel-next')));
    await tester.tap(find.byKey(const ValueKey('remote-mute')));
    await tester.tap(find.byKey(const ValueKey('remote-random')));

    expect(volumeDown, 1);
    expect(volumeUp, 1);
    expect(previous, 1);
    expect(next, 1);
    expect(mute, 1);
    expect(random, 1);

    await tester.pump(const Duration(seconds: 1));
    expect(find.byKey(const ValueKey('remote-channel-next')), findsNothing);

    await tester.tapAt(const Offset(1, 1));
    await tester.pump();
    expect(find.byKey(const ValueKey('remote-channel-next')), findsOneWidget);
  });

  testWidgets('TV mode does not draw touch buttons', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: RemoteOverlay(isTv: true))),
    );

    expect(find.byKey(const ValueKey('remote-channel-next')), findsNothing);
    expect(find.byKey(const ValueKey('remote-random')), findsOneWidget);
  });

  test('hardware channel keys map without drawing touch controls', () {
    var next = 0;
    var previous = 0;

    expect(
      handleRemoteOverlayInput(
        TvInputKey.channelUp,
        onChannelNext: () => next++,
        onChannelPrevious: () => previous++,
      ),
      TvInputResult.handled,
    );
    expect(
      handleRemoteOverlayInput(
        TvInputKey.channelDown,
        onChannelNext: () => next++,
        onChannelPrevious: () => previous++,
      ),
      TvInputResult.handled,
    );
    expect(next, 1);
    expect(previous, 1);
  });
}
