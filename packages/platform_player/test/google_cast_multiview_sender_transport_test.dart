import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:platform_player/platform_player.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('GoogleCastMultiviewSenderTransport', () {
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

    test('registers the multiview namespace on construction', () async {
      GoogleCastMultiviewSenderTransport();
      await Future<void>.delayed(Duration.zero);

      expect(
        methodCalls,
        contains(
          isA<MethodCall>()
              .having((c) => c.method, 'method', 'setNamespace')
              .having((c) => c.arguments, 'arguments', multiviewCastNamespace),
        ),
      );
    });

    test(
      'sendCommand encodes the command and sends it on the namespace',
      () async {
        final transport = GoogleCastMultiviewSenderTransport();
        await transport.sendCommand(
          const MultiviewPromoteCommand(slotId: 'yrf-music'),
        );

        final sendCall = methodCalls.singleWhere(
          (c) => c.method == 'sendMessage',
        );
        final args = sendCall.arguments as Map;
        expect(args['namespace'], multiviewCastNamespace);
        expect(
          jsonDecode(args['message'] as String),
          const MultiviewPromoteCommand(slotId: 'yrf-music').toJson(),
        );
      },
    );

    test('stateUpdates decodes an incoming multiview.state frame', () async {
      final transport = GoogleCastMultiviewSenderTransport();
      final future = transport.stateUpdates.first;

      await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .handlePlatformMessage(
            channel.name,
            channel.codec.encodeMethodCall(
              MethodCall('onMessageReceived', {
                'namespace': multiviewCastNamespace,
                'message': jsonEncode(
                  const MultiviewCastState(
                    capacity: 2,
                    slots: [
                      MultiviewCastSlot(
                        slotId: 'aajtak-hd',
                        channelId: 'aajtak-hd',
                        channelName: 'Aaj Tak HD',
                        featured: true,
                      ),
                    ],
                  ).toJson(),
                ),
              }),
            ),
            (_) {},
          );

      final state = await future;
      expect(state.capacity, 2);
      expect(state.slots.single.channelId, 'aajtak-hd');
    });

    test('ignores frames on a foreign namespace', () async {
      final transport = GoogleCastMultiviewSenderTransport();
      final states = <MultiviewCastState>[];
      final sub = transport.stateUpdates.listen(states.add);

      await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .handlePlatformMessage(
            channel.name,
            channel.codec.encodeMethodCall(
              const MethodCall('onMessageReceived', {
                'namespace': 'urn:x-cast:something.else',
                'message': '{"type":"multiview.state","capacity":1,"slots":[]}',
              }),
            ),
            (_) {},
          );
      await Future<void>.delayed(Duration.zero);

      expect(states, isEmpty);
      await sub.cancel();
    });

    test(
      'ignores a malformed frame on its own namespace instead of throwing',
      () async {
        final transport = GoogleCastMultiviewSenderTransport();
        final states = <MultiviewCastState>[];
        final sub = transport.stateUpdates.listen(states.add);

        await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .handlePlatformMessage(
              channel.name,
              channel.codec.encodeMethodCall(
                MethodCall('onMessageReceived', {
                  'namespace': multiviewCastNamespace,
                  'message': 'not json',
                }),
              ),
              (_) {},
            );
        await Future<void>.delayed(Duration.zero);

        expect(states, isEmpty);
        await sub.cancel();
      },
    );
  });
}
