import 'package:feature_iptv/presentation/tv_ux/tv_loading_screen.dart';
import 'package:feature_iptv/presentation/widgets/channel_logo.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:platform_channels/platform_channels.dart';

void main() {
  const testChannel = IPTVChannel(
    id: 'channel-1',
    name: 'Example Channel',
    streamUrl: 'https://example.test/stream.m3u8',
  );
  const testChannel2 = IPTVChannel(
    id: 'channel-2',
    name: 'Another Channel',
    streamUrl: 'https://example.test/stream2.m3u8',
  );

  Widget wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

  testWidgets('shows the channel logo when a channel is provided', (
    tester,
  ) async {
    await tester.pumpWidget(wrap(const TvLoadingScreen(channel: testChannel)));
    expect(find.byType(ChannelLogo), findsOneWidget);
  });

  testWidgets('shows spinner-only (no crash) when channel is null', (
    tester,
  ) async {
    await tester.pumpWidget(wrap(const TvLoadingScreen(channel: null)));
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.byType(ChannelLogo), findsNothing);
  });

  testWidgets('zoom-out sequence runs to completion when ready flips true', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap(const TvLoadingScreen(channel: testChannel, ready: false)),
    );

    // Not yet animating: logo at rest (scale 1, opacity 1).
    var transform = tester.widget<Transform>(
      find.byKey(const ValueKey('tv-loading-screen-logo-transform')),
    );
    var fade = tester.widget<FadeTransition>(
      find.byKey(const ValueKey('tv-loading-screen-logo-fade')),
    );
    expect(transform.transform.storage[0], closeTo(1.0, 0.001));
    expect(fade.opacity.value, closeTo(1.0, 0.001));

    await tester.pumpWidget(
      wrap(const TvLoadingScreen(channel: testChannel, ready: true)),
    );
    await tester.pump(); // start the animation
    await tester.pump(const Duration(milliseconds: 175)); // mid-animation

    transform = tester.widget<Transform>(
      find.byKey(const ValueKey('tv-loading-screen-logo-transform')),
    );
    fade = tester.widget<FadeTransition>(
      find.byKey(const ValueKey('tv-loading-screen-logo-fade')),
    );
    final midScale = transform.transform.storage[0];
    final midOpacity = fade.opacity.value;
    expect(midScale, greaterThan(0.6));
    expect(midScale, lessThan(1.0));
    expect(midOpacity, greaterThan(0.0));
    expect(midOpacity, lessThan(1.0));

    await tester.pump(const Duration(milliseconds: 200)); // past ~350ms total

    transform = tester.widget<Transform>(
      find.byKey(const ValueKey('tv-loading-screen-logo-transform')),
    );
    fade = tester.widget<FadeTransition>(
      find.byKey(const ValueKey('tv-loading-screen-logo-fade')),
    );
    expect(transform.transform.storage[0], closeTo(0.6, 0.001));
    expect(fade.opacity.value, closeTo(0.0, 0.001));
  });

  testWidgets(
    'switching channel mid-animation does not leak the old AnimationController',
    (tester) async {
      await tester.pumpWidget(
        wrap(const TvLoadingScreen(channel: testChannel, ready: true)),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100)); // interrupt

      await tester.pumpWidget(
        wrap(const TvLoadingScreen(channel: testChannel2, ready: false)),
      );
      // Bounded pumps rather than pumpAndSettle: the loading screen always
      // shows an indeterminate CircularProgressIndicator, whose ticker never
      // idles, so pumpAndSettle would time out regardless of the
      // AnimationController fix under test.
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump(const Duration(milliseconds: 400));

      expect(tester.takeException(), isNull);
    },
  );
}
