import 'package:flutter_test/flutter_test.dart';
import 'package:platform_player/platform_player.dart';

void main() {
  test('playback stats preserve exact engine facts and can be cleared', () {
    const stats = AiroPlaybackStats(
      codec: 'hevc',
      width: 3840,
      height: 2160,
      bitrateKbps: 12000,
    );

    final withStats = StreamingState().copyWith(playbackStats: stats);
    expect(withStats.playbackStats, stats);
    expect(withStats.playbackStats?.resolution, '3840x2160');
    expect(withStats.copyWith(clearPlaybackStats: true).playbackStats, isNull);
  });

  test('partial engine facts remain partial', () {
    const stats = AiroPlaybackStats(codec: 'av1');

    expect(stats.hasValues, isTrue);
    expect(stats.resolution, isNull);
    expect(stats.bitrateKbps, isNull);
  });
}
