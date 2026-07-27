import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Android Cast media adapter has no native log sink', () {
    final source = File(
      'third_party/flutter_chrome_cast/android/src/main/kotlin/'
      'com/felnanuke/google_cast/RemoteMediaClientMethodChannel.kt',
    ).readAsStringSync();

    expect(source, isNot(contains('android.util.Log')));
    expect(source, isNot(contains('Log.')));
  });
}
