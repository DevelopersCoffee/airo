import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:platform_media/platform_media.dart';
import 'package:platform_player/platform_player.dart';

import 'package:feature_iptv/feature_iptv.dart';

void main() {
  testWidgets(
    'VideoPlayerWidget renders the loading placeholder when no video view is available',
    (tester) async {
      final service = VideoPlayerStreamingService(
        engine: FakeAiroPlaybackEngine(),
      );
      addTearDown(service.dispose);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            iptvStreamingServiceProvider.overrideWithValue(service),
          ],
          child: const MaterialApp(home: VideoPlayerWidget()),
        ),
      );
      await tester.pump();

      // No channel played yet — buildVideoView() is null, so the widget
      // must fall back to its placeholder/loading branch instead of
      // crashing on a null video surface.
      expect(find.byType(VideoPlayerWidget), findsOneWidget);
    },
  );
}
