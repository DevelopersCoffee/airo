import 'package:flutter_test/flutter_test.dart';

import 'package:platform_media/platform_media.dart';
import 'package:platform_player/platform_player.dart';

void main() {
  test('video player streaming service starts idle', () async {
    final service = VideoPlayerStreamingService();

    expect(service.currentState.playbackState, PlaybackState.idle);
    await service.dispose();
  });
}
