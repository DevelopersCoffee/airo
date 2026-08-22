import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:feature_mind/src/capture/domain/live_transcription_support.dart';

void main() {
  test('desktop hosts support live preview', () {
    for (final host in [
      TargetPlatform.macOS,
      TargetPlatform.linux,
      TargetPlatform.windows,
    ]) {
      expect(liveTranscriptionPreviewSupported(platform: host), isTrue);
    }
  });

  test('mobile hosts do not support live preview', () {
    for (final host in [TargetPlatform.android, TargetPlatform.iOS]) {
      expect(liveTranscriptionPreviewSupported(platform: host), isFalse);
      expect(liveTranscriptionMobileHost(platform: host), isTrue);
    }
  });

  test('unavailable message mentions desktop-only on mobile', () {
    expect(
      liveTranscriptionUnavailableMessage(platform: TargetPlatform.android),
      contains('desktop-only'),
    );
  });
}
