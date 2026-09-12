import 'package:feature_iptv/presentation/tv_ux/sections/channel_name_overlay.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:platform_channels/platform_channels.dart';

void main() {
  const channel = IPTVChannel(
    id: 'one',
    name: 'Channel One',
    streamUrl: 'https://one',
    group: 'News',
  );
  const otherChannel = IPTVChannel(
    id: 'two',
    name: 'Channel Two',
    streamUrl: 'https://two',
    group: 'News',
  );

  // The overlay returns a Positioned, so it always needs a Stack parent —
  // the same Stack `_VideoStageWithActions` gives it in the real shell.
  Widget wrap(Widget overlay) {
    return MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 640,
          height: 360,
          child: Stack(
            fit: StackFit.expand,
            children: [
              const ColoredBox(color: Colors.black),
              overlay,
            ],
          ),
        ),
      ),
    );
  }

  double opacityOf(WidgetTester tester) {
    return tester
        .widget<AnimatedOpacity>(
          find.byKey(const ValueKey('airo-tv-channel-name-overlay')),
        )
        .opacity;
  }

  testWidgets('shows channel name, logo and LIVE badge when a channel is set', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap(const ChannelNameOverlay(channel: channel, dismissRequested: false)),
    );

    expect(find.text('Channel One'), findsOneWidget);
    expect(find.text('LIVE'), findsOneWidget);
    expect(opacityOf(tester), 1);
  });

  testWidgets('renders nothing at all without a channel', (tester) async {
    await tester.pumpWidget(
      wrap(const ChannelNameOverlay(channel: null, dismissRequested: false)),
    );

    expect(
      find.byKey(const ValueKey('airo-tv-channel-name-overlay')),
      findsNothing,
    );
  });

  testWidgets('auto-hides after 5s of no input', (tester) async {
    await tester.pumpWidget(
      wrap(const ChannelNameOverlay(channel: channel, dismissRequested: false)),
    );
    expect(opacityOf(tester), 1);

    await tester.pump(const Duration(seconds: 6));
    await tester.pumpAndSettle();

    // The widget stays mounted (it still owns the stage activity surface) —
    // only its opacity goes to zero, so assert that rather than findsNothing.
    expect(find.text('Channel One'), findsOneWidget);
    expect(opacityOf(tester), 0);
  });

  testWidgets('reappears and resets its timer on pointer input', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap(const ChannelNameOverlay(channel: channel, dismissRequested: false)),
    );
    await tester.pump(const Duration(seconds: 6));
    await tester.pumpAndSettle();
    expect(opacityOf(tester), 0);

    // Anywhere on the stage counts as activity, not just the badge itself.
    await tester.tapAt(const Offset(400, 300));
    await tester.pumpAndSettle();
    expect(opacityOf(tester), 1);

    // Timer restarted from the tap: still visible at 4s, gone by 6s.
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
    expect(opacityOf(tester), 1);

    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    expect(opacityOf(tester), 0);
  });

  testWidgets('a channel change reveals it again', (tester) async {
    await tester.pumpWidget(
      wrap(const ChannelNameOverlay(channel: channel, dismissRequested: false)),
    );
    await tester.pump(const Duration(seconds: 6));
    await tester.pumpAndSettle();
    expect(opacityOf(tester), 0);

    await tester.pumpWidget(
      wrap(
        const ChannelNameOverlay(
          channel: otherChannel,
          dismissRequested: false,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Channel Two'), findsOneWidget);
    expect(opacityOf(tester), 1);
  });

  testWidgets('dismissRequested hides it immediately regardless of the timer', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap(const ChannelNameOverlay(channel: channel, dismissRequested: false)),
    );
    expect(opacityOf(tester), 1);

    await tester.pumpWidget(
      wrap(const ChannelNameOverlay(channel: channel, dismissRequested: true)),
    );
    await tester.pumpAndSettle();

    // No 5s wait needed.
    expect(opacityOf(tester), 0);
  });

  testWidgets('dismissRequested blocks reveals while it stays true', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap(const ChannelNameOverlay(channel: channel, dismissRequested: true)),
    );
    await tester.pumpAndSettle();
    expect(opacityOf(tester), 0);

    // Neither pointer activity...
    await tester.tapAt(const Offset(400, 300));
    await tester.pumpAndSettle();
    expect(opacityOf(tester), 0);

    // ...nor a channel change may raise a second floating layer under an
    // open player-actions sheet.
    await tester.pumpWidget(
      wrap(
        const ChannelNameOverlay(channel: otherChannel, dismissRequested: true),
      ),
    );
    await tester.pumpAndSettle();
    expect(opacityOf(tester), 0);
  });

  testWidgets('the stage activity surface does not swallow taps beneath it', (
    tester,
  ) async {
    var tapsBeneath = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 640,
            height: 360,
            child: Stack(
              fit: StackFit.expand,
              children: [
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => tapsBeneath++,
                  child: const ColoredBox(color: Colors.black),
                ),
                const ChannelNameOverlay(
                  channel: channel,
                  dismissRequested: false,
                ),
              ],
            ),
          ),
        ),
      ),
    );

    await tester.tapAt(const Offset(400, 300));
    await tester.pumpAndSettle();

    expect(tapsBeneath, 1);
  });

  testWidgets('cancels its idle timer on dispose', (tester) async {
    await tester.pumpWidget(
      wrap(const ChannelNameOverlay(channel: channel, dismissRequested: false)),
    );

    await tester.pumpWidget(const MaterialApp(home: Scaffold()));
    // A surviving Timer would trip flutter_test's pending-timer guard here.
    await tester.pump(const Duration(seconds: 6));

    expect(tester.takeException(), isNull);
  });
}
