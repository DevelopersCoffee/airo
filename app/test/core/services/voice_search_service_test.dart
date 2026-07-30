import 'package:airo_app/core/services/voice_search_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('unavailable voice service does not claim release readiness', () async {
    final service = MockVoiceSearchService();
    addTearDown(service.dispose);

    expect(await service.isAvailable(), isFalse);
    final result = await service.startListening();

    expect(result.isSuccess, isFalse);
    expect(result.errorMessage, contains('unavailable'));
    expect(service.state, VoiceSearchState.error);
  });

  test('stopListening returns the service to idle', () async {
    final service = MockVoiceSearchService();
    addTearDown(service.dispose);

    await service.startListening();
    await service.stopListening();

    expect(service.state, VoiceSearchState.idle);
  });

  test(
    'Android speech timeout returns a terminal error and cancels native capture',
    () async {
      const channel = MethodChannel('test.airo.voice_search.timeout');
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      var stopCalls = 0;
      messenger.setMockMethodCallHandler(channel, (call) async {
        if (call.method == 'isAvailable') return true;
        if (call.method == 'startListening') {
          return Future<Object?>.delayed(const Duration(seconds: 1));
        }
        if (call.method == 'stopListening') {
          stopCalls += 1;
          return null;
        }
        return null;
      });
      addTearDown(() => messenger.setMockMethodCallHandler(channel, null));

      final service = AndroidVoiceSearchService(
        channel: channel,
        operationTimeout: const Duration(milliseconds: 10),
        stopTimeout: const Duration(milliseconds: 10),
      );
      addTearDown(service.dispose);

      final result = await service.startListening();

      expect(result.isSuccess, isFalse);
      expect(result.errorMessage, contains('timed out'));
      expect(service.state, VoiceSearchState.error);
      await Future<void>.delayed(Duration.zero);
      expect(stopCalls, 1);
    },
  );

  test('Android stop timeout still restores idle state', () async {
    const channel = MethodChannel('test.airo.voice_search.stop-timeout');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'stopListening') {
        return Future<Object?>.delayed(const Duration(seconds: 1));
      }
      return true;
    });
    addTearDown(() => messenger.setMockMethodCallHandler(channel, null));

    final service = AndroidVoiceSearchService(
      channel: channel,
      stopTimeout: const Duration(milliseconds: 10),
    );
    addTearDown(service.dispose);

    await service.stopListening();

    expect(service.state, VoiceSearchState.idle);
  });
}
