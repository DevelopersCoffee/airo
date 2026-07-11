import 'package:flutter_test/flutter_test.dart';

import 'package:platform_media/platform_media.dart';

void main() {
  test('creates video player streaming service', () {
    final service = VideoPlayerStreamingService();
    expect(service.currentState.currentChannel, isNull);
  });
}
