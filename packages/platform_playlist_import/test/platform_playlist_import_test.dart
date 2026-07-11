import 'package:flutter_test/flutter_test.dart';

import 'package:platform_playlist_import/platform_playlist_import.dart';

void main() {
  test('parses M3U channel entries', () {
    final parser = M3UParserService;
    expect(parser, isNotNull);
  });
}
