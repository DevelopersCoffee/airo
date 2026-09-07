import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:platform_player/platform_player.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AiroCastReceiverMultiviewTransport', () {
    const channel = MethodChannel(
      'com.developerscoffee.airo/cast_multiview_receiver',
    );
    late List<MethodCall> methodCalls;

    setUp(() {
      methodCalls = [];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            methodCalls.add(call);
            return null;
          });
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    test('publishState encodes state and invokes publishState', () async {
      final transport = AiroCastReceiverMultiviewTransport();
      await transport.publishState(
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
        ),
      );

      final call = methodCalls.single;
      expect(call.method, 'publishState');
      final decoded = jsonDecode((call.arguments as Map)['message'] as String);
      expect(decoded, {
        'type': 'multiview.state',
        'capacity': 2,
        'slots': [
          {
            'slotId': 'aajtak-hd',
            'channelId': 'aajtak-hd',
            'channelName': 'Aaj Tak HD',
            'featured': true,
          },
        ],
      });
    });

    test('an onCommand call decodes and surfaces on the commands stream', () async {
      final transport = AiroCastReceiverMultiviewTransport();
      final future = transport.commands.first;

      await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .handlePlatformMessage(
            channel.name,
            channel.codec.encodeMethodCall(
              MethodCall('onCommand', {
                'message': jsonEncode(
                  const MultiviewPromoteCommand(slotId: 'yrf-music').toJson(),
                ),
              }),
            ),
            (_) {},
          );

      final command = await future;
      expect(command, const MultiviewPromoteCommand(slotId: 'yrf-music'));
    });

    test('ignores a malformed onCommand payload instead of throwing', () async {
      final transport = AiroCastReceiverMultiviewTransport();
      final commands = <MultiviewCastCommand>[];
      final sub = transport.commands.listen(commands.add);

      await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .handlePlatformMessage(
            channel.name,
            channel.codec.encodeMethodCall(
              const MethodCall('onCommand', {'message': 'not json'}),
            ),
            (_) {},
          );
      await Future<void>.delayed(Duration.zero);

      expect(commands, isEmpty);
      await sub.cancel();
    });
  });
}
