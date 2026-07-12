import 'package:flutter_test/flutter_test.dart';

import 'package:platform_streams/platform_streams.dart';

void main() {
  test('live edge detector can be constructed and disposed', () {
    final detector = LiveEdgeDetector();

    detector.dispose();
  });
}
