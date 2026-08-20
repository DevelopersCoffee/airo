import 'package:feature_mind/src/services/voice_search_service.dart';
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

  test(
    'Android speech success emits completed state with confidence',
    () async {
      const channel = MethodChannel('test.airo.voice_search.success');
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(channel, (call) async {
        if (call.method == 'isAvailable') return true;
        if (call.method == 'startListening') {
          return {'text': 'open model advisor', 'confidence': 0.84};
        }
        if (call.method == 'stopListening') return null;
        return null;
      });
      addTearDown(() => messenger.setMockMethodCallHandler(channel, null));

      final service = AndroidVoiceSearchService(channel: channel);
      addTearDown(service.dispose);

      final result = await service.startListening();

      expect(result.isSuccess, isTrue);
      expect(result.text, 'open model advisor');
      expect(result.confidence, 0.84);
      expect(service.state, VoiceSearchState.completed);
    },
  );

  test('Android speech reports platform errors without throwing', () async {
    const channel = MethodChannel('test.airo.voice_search.platform-error');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'isAvailable') return true;
      if (call.method == 'startListening') {
        throw PlatformException(code: 'speech_error', message: 'Mic denied');
      }
      return null;
    });
    addTearDown(() => messenger.setMockMethodCallHandler(channel, null));

    final service = AndroidVoiceSearchService(channel: channel);
    addTearDown(service.dispose);

    final result = await service.startListening();

    expect(result.isSuccess, isFalse);
    expect(result.errorMessage, 'Mic denied');
    expect(service.state, VoiceSearchState.error);
  });

  test('desktop whisper path never throws when permission is denied', () async {
    final service = DesktopWhisperVoiceSearchService(
      hasPermission: () async => false,
      startCapture: (_) async => fail('must not start the encoder'),
      stopCapture: () async => fail('must not stop the encoder'),
      transcribe: (_) async => fail('must not transcribe'),
      tempPath: () async => '/tmp/unused.wav',
    );
    addTearDown(service.dispose);

    final result = await service.startListening();

    expect(result.isSuccess, isFalse);
    expect(result.errorMessage, contains('Microphone access'));
    expect(service.state, VoiceSearchState.error);
  });

  test('desktop whisper path transcribes after stop', () async {
    var started = false;
    String? capturedPath;
    final service = DesktopWhisperVoiceSearchService(
      hasPermission: () async => true,
      startCapture: (path) async {
        started = true;
        capturedPath = path;
      },
      stopCapture: () async => capturedPath,
      transcribe: (path) async {
        expect(path, capturedPath);
        return 'what is on my calendar today';
      },
      tempPath: () async => '/tmp/airo-voice-test.wav',
    );
    addTearDown(service.dispose);

    final pending = service.startListening();
    await Future<void>.delayed(Duration.zero);
    expect(started, isTrue);
    expect(service.state, VoiceSearchState.listening);
    await service.stopListening();
    final result = await pending;

    expect(result.isSuccess, isTrue);
    expect(result.text, 'what is on my calendar today');
  });

  test('desktop whisper path returns an error instead of throwing', () async {
    final service = DesktopWhisperVoiceSearchService(
      hasPermission: () async => true,
      startCapture: (_) async => throw StateError('encoder exploded'),
      stopCapture: () async => null,
      transcribe: (_) async => '',
      tempPath: () async => '/tmp/airo-voice-test.wav',
    );
    addTearDown(service.dispose);

    final result = await service.startListening();

    expect(result.isSuccess, isFalse);
    expect(result.errorMessage, contains('Voice input failed'));
    expect(service.state, VoiceSearchState.error);
  });
}
