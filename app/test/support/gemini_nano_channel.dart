import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// The platform channel `GeminiNanoService` talks to.
const geminiNanoChannel = MethodChannel('com.airo.gemini_nano');

/// Answers the Gemini Nano platform channel for the duration of a test.
///
/// Every call in `GeminiNanoService` is bounded with `.timeout(...)` so a wedged
/// AICore cannot hang the app. Under `flutter_test` a channel with no handler
/// never answers, so that timeout's `Timer` is still pending when the widget
/// tree is torn down and the run fails on `!timersPending` — which is what took
/// out ten tests across three chat suites.
///
/// Stubbing the channel lets those bounded calls complete. The defaults report
/// Nano as unavailable, which is the truth for a test host: no AICore, no
/// device info.
void stubGeminiNanoChannel({bool available = false, bool initialized = false}) {
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  messenger.setMockMethodCallHandler(geminiNanoChannel, (call) async {
    return switch (call.method) {
      'isAvailable' => available,
      'initialize' => initialized,
      'getDeviceInfo' => <String, Object?>{},
      // 'dispose' and anything else: acknowledge so the bounded call completes
      // rather than leaving its timeout armed.
      _ => null,
    };
  });
  addTearDown(
    () => messenger.setMockMethodCallHandler(geminiNanoChannel, null),
  );
}
