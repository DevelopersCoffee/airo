import 'package:airo_app/features/agent_chat/data/connectors/calendar_connector.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('NativeCalendarConnector', () {
    test('reads events through the native calendar method channel', () async {
      TestWidgetsFlutterBinding.ensureInitialized();
      const channel = MethodChannel('test.agent_connectors.calendar_read');
      final calls = <MethodCall>[];

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            calls.add(call);
            return {
              'date': call.arguments['date'],
              'events': [
                {
                  'title': 'Design review',
                  'start': '2026-06-22T10:00:00+05:30',
                  'end': '2026-06-22T10:30:00+05:30',
                  'calendar': 'Work',
                },
              ],
            };
          });
      addTearDown(() {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null);
      });

      final connector = NativeCalendarConnector(channel: channel);

      final result = await connector.execute({'date': '2026-06-22'});

      expect(result.isError, isFalse);
      expect(result.data['date'], '2026-06-22');
      expect(result.data['events'], isA<List>());
      expect(calls.single.method, 'readCalendarEvents');
      expect(calls.single.arguments, {'date': '2026-06-22'});
    });

    test('maps native calendar errors to connector errors', () async {
      TestWidgetsFlutterBinding.ensureInitialized();
      const channel = MethodChannel('test.agent_connectors.calendar_error');

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (_) async {
            return {
              'error': 'calendar_permission_denied',
              'message':
                  'Calendar permission is required to check your schedule.',
            };
          });
      addTearDown(() {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null);
      });

      final connector = NativeCalendarConnector(channel: channel);

      final result = await connector.execute({'date': '2026-06-22'});

      expect(result.isError, isTrue);
      expect(result.errorCode, 'calendar_permission_denied');
      expect(result.message, contains('permission'));
    });
  });
}
