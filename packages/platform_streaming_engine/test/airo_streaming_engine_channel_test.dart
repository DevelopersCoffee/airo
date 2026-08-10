import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:platform_streaming_engine/platform_streaming_engine.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('com.airo.player/streaming_engine');
  final calls = <MethodCall>[];
  bool pingResult = true;
  Map<Object?, Object?> shadowFetchResult = {'status': 'measured', 'throughputKbps': 4200.0};
  bool switchSourceResult = true;

  setUp(() {
    calls.clear();
    pingResult = true;
    shadowFetchResult = {'status': 'measured', 'throughputKbps': 4200.0};
    switchSourceResult = true;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          switch (call.method) {
            case 'ping':
              return pingResult;
            case 'preWarm':
              return null;
            case 'shadowFetch':
              return shadowFetchResult;
            case 'switchSource':
              return switchSourceResult;
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

  group('AiroStreamingEngineChannel.preWarm', () {
    test('forwards the host list to the platform', () async {
      await AiroStreamingEngineChannel.preWarm(['a.example.com', 'b.example.com']);

      expect(calls.single.method, 'preWarm');
      expect(calls.single.arguments, {
        'hosts': ['a.example.com', 'b.example.com'],
      });
    });

    test('does not throw when no platform implementation is registered', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            throw MissingPluginException();
          });

      await AiroStreamingEngineChannel.preWarm(['example.com']);
    });

    test('does not throw on an unexpected platform error', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            throw PlatformException(code: 'boom');
          });

      await AiroStreamingEngineChannel.preWarm(['example.com']);
    });

    test('an empty host list is still forwarded (native no-ops on empty)', () async {
      await AiroStreamingEngineChannel.preWarm([]);

      expect(calls.single.arguments, {'hosts': <String>[]});
    });
  });

  group('AiroStreamingEngineChannel.shadowFetch', () {
    test('returns a measured outcome on success', () async {
      final outcome = await AiroStreamingEngineChannel.shadowFetch('https://example.com/a.ts');

      expect(calls.single.method, 'shadowFetch');
      expect(calls.single.arguments, {'url': 'https://example.com/a.ts'});
      expect(outcome, isA<AiroShadowFetchMeasured>());
      expect((outcome as AiroShadowFetchMeasured).throughputKbps, 4200.0);
    });

    test('returns a failed outcome with the native reason', () async {
      shadowFetchResult = {'status': 'failed', 'reason': 'HTTP 404'};

      final outcome = await AiroStreamingEngineChannel.shadowFetch('https://example.com/a.ts');

      expect(outcome, isA<AiroShadowFetchFailed>());
      expect((outcome as AiroShadowFetchFailed).reason, 'HTTP 404');
    });

    test('returns busy when the native limiter rejects the probe', () async {
      shadowFetchResult = {'status': 'busy'};

      final outcome = await AiroStreamingEngineChannel.shadowFetch('https://example.com/a.ts');

      expect(outcome, isA<AiroShadowFetchBusy>());
    });

    test('degrades to failed when no platform implementation is registered', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            throw MissingPluginException();
          });

      final outcome = await AiroStreamingEngineChannel.shadowFetch('https://example.com/a.ts');

      expect(outcome, isA<AiroShadowFetchFailed>());
    });
  });

  group('AiroStreamingEngineChannel.switchSource', () {
    test('returns the platform result on success', () async {
      final result = await AiroStreamingEngineChannel.switchSource('https://example.com/b.ts');

      expect(calls.single.method, 'switchSource');
      expect(calls.single.arguments, {'url': 'https://example.com/b.ts'});
      expect(result, isTrue);
    });

    test('returns false when no active player exists on the native side', () async {
      switchSourceResult = false;

      expect(await AiroStreamingEngineChannel.switchSource('https://example.com/b.ts'), isFalse);
    });

    test('degrades to false when no platform implementation is registered', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            throw MissingPluginException();
          });

      expect(await AiroStreamingEngineChannel.switchSource('https://example.com/b.ts'), isFalse);
    });
  });
}
