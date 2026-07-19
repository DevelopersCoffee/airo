import 'package:feature_iptv/presentation/widgets/player_overlay.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:platform_player/platform_player.dart';

void main() {
  Widget wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

  testWidgets('renders title, subtitle and LIVE pill from state', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap(
        PlayerOverlay(
          state: const PlayerViewState(
            playback: PlaybackState.playing,
            liveState: LiveStreamState.live,
            networkQuality: NetworkQuality.good,
            bufferSeconds: 12,
            qualityLabel: '1080p',
            title: 'Star Sports 1',
            subtitle: 'Cricket Live',
          ),
          onBack: () {},
          onPlayPause: () {},
        ),
      ),
    );

    expect(find.text('Star Sports 1'), findsOneWidget);
    expect(find.text('Cricket Live'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('player-overlay-live-pill')),
        matching: find.text('LIVE'),
      ),
      findsOneWidget,
    );
    expect(find.textContaining('Good'), findsOneWidget);
    expect(find.textContaining('1080p'), findsOneWidget);
  });

  testWidgets('shows failover toast with exact text when failover is set', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap(
        PlayerOverlay(
          state: const PlayerViewState(
            title: 'Star Sports 1',
            failover: FailoverProgress(currentSource: 2, totalSources: 4),
          ),
          onBack: () {},
          onPlayPause: () {},
        ),
      ),
    );

    expect(find.text('Switching to source 2 of 4'), findsOneWidget);
  });

  testWidgets('hides failover toast when failover is null', (tester) async {
    await tester.pumpWidget(
      wrap(
        PlayerOverlay(
          state: const PlayerViewState(title: 'Star Sports 1'),
          onBack: () {},
          onPlayPause: () {},
        ),
      ),
    );

    expect(find.textContaining('Switching to source'), findsNothing);
  });

  testWidgets('auto-hides after autoHideDelay and reveals on tap', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap(
        PlayerOverlay(
          state: const PlayerViewState(title: 'Star Sports 1'),
          onBack: () {},
          onPlayPause: () {},
          autoHideDelay: const Duration(seconds: 3),
        ),
      ),
    );

    // Visible immediately after mount.
    var opacity = tester.widget<AnimatedOpacity>(
      find.byKey(const ValueKey('player-overlay-controls-opacity')),
    );
    expect(opacity.opacity, 1.0);

    // Auto-hide fires after the delay elapses.
    await tester.pump(const Duration(seconds: 4));
    opacity = tester.widget<AnimatedOpacity>(
      find.byKey(const ValueKey('player-overlay-controls-opacity')),
    );
    expect(opacity.opacity, 0.0);

    // Any tap reveals the controls again and restarts the timer.
    await tester.tap(find.byType(PlayerOverlay));
    await tester.pump();
    opacity = tester.widget<AnimatedOpacity>(
      find.byKey(const ValueKey('player-overlay-controls-opacity')),
    );
    expect(opacity.opacity, 1.0);
  });

  testWidgets('play/pause callback fires on center button tap', (
    tester,
  ) async {
    var tapped = false;
    await tester.pumpWidget(
      wrap(
        PlayerOverlay(
          state: const PlayerViewState(
            title: 'Star Sports 1',
            playback: PlaybackState.playing,
          ),
          onBack: () {},
          onPlayPause: () => tapped = true,
        ),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('player-overlay-play-pause')));
    expect(tapped, isTrue);
  });
}
