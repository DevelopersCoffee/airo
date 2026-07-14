import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:platform_media/platform_media.dart';
import 'package:platform_player/platform_player.dart';

void main() {
  test('video player streaming service starts idle', () async {
    final service = VideoPlayerStreamingService();

    expect(service.currentState.playbackState, PlaybackState.idle);
    await service.dispose();
  });

  test('analytics logger rejects prohibited media fields', () {
    final logs = <String>[];
    final previousDebugPrint = debugPrint;
    debugPrint = (String? message, {int? wrapWidth}) {
      if (message != null) logs.add(message);
    };
    addTearDown(() => debugPrint = previousDebugPrint);

    AppLogger.analytics(
      'live_stream_seek',
      params: const {'channel': 'City News Live', 'delay': 5},
    );

    expect(logs.single, contains('rejected:live_stream_seek'));
    expect(logs.single, contains('channel:prohibited_field_name'));
    expect(logs.single, isNot(contains('City News Live')));
  });
}
