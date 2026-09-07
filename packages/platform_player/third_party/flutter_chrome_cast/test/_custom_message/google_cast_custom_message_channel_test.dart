import 'package:flutter/services.dart';
import 'package:flutter_chrome_cast/custom_message.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('GoogleCastCustomMessageChannel', () {
    const channel = MethodChannel('com.felnanuke.google_cast.custom_message');
    late List<MethodCall> methodCalls;

    setUp(() {
      methodCalls = [];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
        methodCalls.add(call);
        return true;
      });
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    test('listen invokes setNamespace with the given namespace', () async {
      await GoogleCastCustomMessageChannel.instance.listen('urn:x-cast:test');

      expect(methodCalls, hasLength(1));
      expect(methodCalls.single.method, 'setNamespace');
      expect(methodCalls.single.arguments, 'urn:x-cast:test');
    });

    test('sendMessage invokes sendMessage with namespace and message',
        () async {
      await GoogleCastCustomMessageChannel.instance.sendMessage(
        'urn:x-cast:test',
        '{"type":"ping"}',
      );

      expect(methodCalls, hasLength(1));
      expect(methodCalls.single.method, 'sendMessage');
      expect(methodCalls.single.arguments, {
        'namespace': 'urn:x-cast:test',
        'message': '{"type":"ping"}',
      });
    });

    test('an onMessageReceived call surfaces on the messages stream', () async {
      await GoogleCastCustomMessageChannel.instance.listen('urn:x-cast:test');

      final future = GoogleCastCustomMessageChannel.instance.messages.first;
      await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .handlePlatformMessage(
        channel.name,
        channel.codec.encodeMethodCall(
          const MethodCall('onMessageReceived', {
            'namespace': 'urn:x-cast:test',
            'message': '{"type":"multiview.state"}',
          }),
        ),
        (_) {},
      );

      final received = await future;
      expect(received.namespace, 'urn:x-cast:test');
      expect(received.message, '{"type":"multiview.state"}');
    });
  });
}
