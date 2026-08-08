import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:platform_streaming_engine/platform_streaming_engine.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('com.airo.player/streaming_engine');
  final calls = <MethodCall>[];
  bool pingResult = true;

  setUp(() {
    calls.clear();
    pingResult = true;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          switch (call.method) {
            case 'ping':
              return pingResult;
            default:
              return null;
          }
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  group('AiroStreamingEngineChannel.ping', () {
    test('returns the platform value on a round trip', () async {
      expect(await AiroStreamingEngineChannel.ping(), isTrue);
      expect(calls.single.method, 'ping');
    });

    test('reflects a false platform response', () async {
      pingResult = false;
      expect(await AiroStreamingEngineChannel.ping(), isFalse);
    });

    test('degrades to false when no platform implementation is registered', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            throw MissingPluginException();
          });

      expect(await AiroStreamingEngineChannel.ping(), isFalse);
    });

    test('degrades to false on an unexpected platform error', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            throw PlatformException(code: 'boom');
          });

      expect(await AiroStreamingEngineChannel.ping(), isFalse);
    });
  });
}
