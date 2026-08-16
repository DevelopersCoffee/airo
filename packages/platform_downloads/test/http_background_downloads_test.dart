import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:platform_downloads/platform_downloads.dart';

void main() {
  test('getQueue is empty before any enqueue', () async {
    final downloads = HttpBackgroundDownloads();
    final snapshot = await downloads.getQueue();
    expect(snapshot.entries, isEmpty);
  });

  test('desktop factory selects HTTP downloads', () {
    if (kIsWeb) {
      expect(createBackgroundDownloads(), isA<HttpBackgroundDownloads>());
      return;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
      case TargetPlatform.iOS:
        expect(
          createBackgroundDownloads(),
          isA<MethodChannelBackgroundDownloads>(),
        );
      default:
        expect(createBackgroundDownloads(), isA<HttpBackgroundDownloads>());
    }
  });
}
