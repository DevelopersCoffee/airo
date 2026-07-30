import 'package:airo_app/core/accessibility/airo_speech_service.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('flutter_tts');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  tearDown(() {
    messenger.setMockMethodCallHandler(channel, null);
  });

  test('speak ignores empty text and stops configured speech', () async {
    final calls = <String>[];
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call.method);
      return 1;
    });

    expect(await AiroSpeechService.instance.speak('   '), isFalse);
    expect(await AiroSpeechService.instance.speak('Read this aloud'), isTrue);
    expect(await AiroSpeechService.instance.stop(), isTrue);

    expect(calls, containsAll(['awaitSpeakCompletion', 'setSpeechRate']));
    expect(calls.where((method) => method == 'stop'), hasLength(2));
    expect(calls, contains('speak'));
  });

  test('platform errors are reported as read-aloud unavailable', () async {
    messenger.setMockMethodCallHandler(channel, (call) async {
      throw PlatformException(code: 'tts_unavailable');
    });

    expect(await AiroSpeechService.instance.speak('hello'), isFalse);
    expect(await AiroSpeechService.instance.stop(), isFalse);
  });
}
