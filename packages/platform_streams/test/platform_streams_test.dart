import 'package:flutter_test/flutter_test.dart';

import 'package:platform_streams/platform_streams.dart';

void main() {
  test('creates a VOD live edge state', () {
    final state = LiveEdgeState.vod();
    expect(state.isLiveStream, false);
  });
}
