import 'package:flutter_test/flutter_test.dart';

import 'package:platform_player/platform_player.dart';

void main() {
  test('rejects unsupported cast streams', () {
    const adapter = IptvCastMediaAdapter();
    final result = adapter.toCastRequest(
      const IPTVChannel(
        id: 'local',
        name: 'Local file',
        streamUrl: 'file:///tmp/video.mp4',
      ),
    );

    expect(result.isCastable, false);
    expect(result.error?.code, AiroCastErrorCode.unsupportedStream);
  });
}
