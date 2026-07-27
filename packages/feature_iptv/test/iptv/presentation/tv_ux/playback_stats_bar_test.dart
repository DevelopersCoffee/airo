import 'package:feature_iptv/presentation/tv_ux/sections/playback_stats_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:platform_player/platform_player.dart';

void main() {
  testWidgets('renders exact available playback facts', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            height: 48,
            child: PlaybackStatsBar(
              stats: AiroPlaybackStats(
                codec: 'h264',
                width: 1920,
                height: 1080,
                bitrateKbps: 5000,
              ),
            ),
          ),
        ),
      ),
    );

    expect(find.text('H264'), findsOneWidget);
    expect(find.text('1920x1080'), findsOneWidget);
    expect(find.text('5000 kbps'), findsOneWidget);
  });

  testWidgets('omits facts the engine did not report', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            height: 48,
            child: PlaybackStatsBar(stats: AiroPlaybackStats(codec: 'av1')),
          ),
        ),
      ),
    );

    expect(find.text('AV1'), findsOneWidget);
    expect(find.textContaining('kbps'), findsNothing);
    expect(find.textContaining('x'), findsNothing);
  });
}
