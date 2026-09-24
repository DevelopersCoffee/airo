import 'package:feature_iptv/presentation/tv_ux/browse_grid_tv_peek_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:platform_channels/platform_channels.dart';
import 'package:platform_media/platform_media.dart';
import 'package:platform_player/platform_player.dart';

void main() {
  const channel = IPTVChannel(
    id: 'news-1',
    name: 'City News Live',
    streamUrl: 'https://example.com/news.m3u8',
  );

  test('releaseBeforePlay stops and disposes the active preview', () async {
    final recordings = <_RecordingPeekPreview>[];
    final controller = BrowseGridTvPeekController(
      previewFactory: () {
        final preview = _RecordingPeekPreview();
        recordings.add(preview);
        return preview;
      },
    );
    addTearDown(controller.dispose);

    controller.onTileFocused(channel, LayerLink());
    await Future<void>.delayed(BrowseGridTvPeekController.settleDuration);
    await Future<void>.delayed(const Duration(milliseconds: 50));

    expect(recordings, isNotEmpty);
    await controller.releaseBeforePlay();

    expect(recordings.last.teardownOrder, ['stop', 'dispose']);
    expect(recordings.last.disposed, isTrue);
  });
}

class _RecordingPeekPreview extends VideoPlayerStreamingService {
  _RecordingPeekPreview()
    : super(engine: FakeAiroPlaybackEngine(), mixWithOthers: true);

  final teardownOrder = <String>[];
  bool disposed = false;

  @override
  Future<void> playChannel(IPTVChannel channel) async {}

  @override
  Future<void> stop() async {
    teardownOrder.add('stop');
    await Future<void>.value();
    await super.stop();
  }

  @override
  Future<void> dispose() async {
    if (disposed) return;
    disposed = true;
    teardownOrder.add('dispose');
    await super.dispose();
  }
}
