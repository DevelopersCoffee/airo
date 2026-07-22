import 'package:feature_iptv/feature_iptv.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';

// #1002: while system PiP is active, IPTVScreen renders only the video
// surface (no AppBar / drawer / browse chrome) so the floating PiP window
// shows just the stream; exiting PiP restores the full UI.
final _channels = [
  const IPTVChannel(
    id: 'c1',
    name: 'Channel One',
    streamUrl: 'https://example.com/c1.m3u8',
    group: 'News',
    category: ChannelCategory.news,
  ),
];

/// Streaming service double mirroring iptv_screen_lifecycle_test.dart — the
/// real service constructs an actual VideoPlayerController against a fake
/// URL, which never finishes initializing and leaks past test teardown.
class _RecordingStreamingService extends VideoPlayerStreamingService {
  _RecordingStreamingService() : super(engine: FakeAiroPlaybackEngine());
}

List<Override> _overrides({required bool pipActive}) => [
  iptvChannelsProvider.overrideWith((ref) async => _channels),
  recentlyWatchedChannelsProvider.overrideWith((ref) async => const []),
  pictureInPictureActiveProvider.overrideWith((ref) => pipActive),
  streamingStateProvider.overrideWith(
    (ref) => Stream.value(
      StreamingState(
        playbackState: PlaybackState.idle,
        isLiveStream: true,
        liveDelay: const Duration(seconds: 1),
      ),
    ),
  ),
  iptvStreamingServiceProvider.overrideWith((ref) {
    final service = _RecordingStreamingService();
    ref.onDispose(service.dispose);
    return service;
  }),
];

void main() {
  testWidgets('PiP active renders a video-only surface without app chrome', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: _overrides(pipActive: true),
        child: const MaterialApp(home: IPTVScreen()),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byType(AppBar), findsNothing);
    expect(find.byType(Drawer), findsNothing);
    expect(find.byType(VideoPlayerWidget), findsOneWidget);
  });

  testWidgets('PiP inactive renders the normal browse UI with app bar', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: _overrides(pipActive: false),
        child: const MaterialApp(home: IPTVScreen()),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byType(AppBar), findsOneWidget);
  });
}
