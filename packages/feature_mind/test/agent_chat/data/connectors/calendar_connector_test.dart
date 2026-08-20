import 'package:feature_mind/src/agent_chat/data/connectors/calendar_connector.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:platform_calendar/platform_calendar.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channelName = calendarMethodChannelName;
  const methodChannel = MethodChannel(channelName);

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(methodChannel, null);
  });

  group('InMemoryCalendarConnector', () {
    test('returns events for a requested date range', () async {
      final connector = InMemoryCalendarConnector(
        events: {
          '2026-06-20': const [
            CalendarEventData(
              title: 'Team standup',
              start: '2026-06-20T10:00:00+05:30',
              end: '2026-06-20T10:30:00+05:30',
              calendar: 'Work',
            ),
          ],
          '2026-06-21': const [
            CalendarEventData(
              title: 'Doctor visit',
              start: '2026-06-21T09:00:00+05:30',
              end: '2026-06-21T09:30:00+05:30',
              calendar: 'Personal',
            ),
          ],
        },
      );

      final result = await connector.execute({
        'date': '2026-06-20',
        'end_date': '2026-06-21',
      });

      expect(result.isError, false);
      expect(result.data['date'], '2026-06-20');
      expect(result.data['end_date'], '2026-06-21');
      expect((result.data['events'] as List), hasLength(2));
    });

    test('rejects missing or inverted date ranges', () async {
      final connector = InMemoryCalendarConnector();

      final missingDate = await connector.execute({});
      final invertedRange = await connector.execute({
        'date': '2026-06-21',
        'end_date': '2026-06-20',
      });

      expect(missingDate.isError, true);
      expect(missingDate.errorCode, 'missing_date');
      expect(invertedRange.isError, true);
      expect(invertedRange.errorCode, 'invalid_date_range');
    });
  });

  group('InMemoryCreateCalendarEventConnector', () {
    test('records validated events', () async {
      final connector = InMemoryCreateCalendarEventConnector();

      final result = await connector.execute({
        'title': 'Bills review',
        'date': '2026-06-20',
        'hour': 19,
        'minute': 15,
      });

      expect(result.isError, false);
      expect(connector.createdEvents, hasLength(1));
      expect(connector.createdEvents.single['title'], 'Bills review');
      expect(result.data['created'], true);
    });
  });

  group('NativeCalendarConnector', () {
    test('reads events through CalendarService', () async {
      final calendar = InMemoryCalendarService(
        events: [
          CalendarEvent(
            id: '1',
            title: 'Team standup',
            start: DateTime(2026, 6, 20, 10),
            end: DateTime(2026, 6, 20, 10, 30),
            calendar: 'Work',
          ),
        ],
      );
      final connector = NativeCalendarConnector(calendar: calendar);
      final result = await connector.execute({
        'date': '2026-06-20',
        'end_date': '2026-06-21',
      });

      expect(result.isError, false);
      expect((result.data['events'] as List), hasLength(1));
    });

    test('surfaces permission required responses', () async {
      final connector = NativeCalendarConnector(
        calendar: InMemoryCalendarService(
          permission: CalendarPermissionStatus.notDetermined,
        ),
      );
      final result = await connector.execute({'date': '2026-06-20'});

      expect(result.isError, true);
      expect(result.errorCode, 'PERMISSION_REQUIRED');
    });

    test('does not fabricate events on unsupported platforms', () async {
      final connector = NativeCalendarConnector(
        calendar: const UnsupportedCalendarService(),
      );

      final result = await connector.execute({'date': '2026-06-20'});

      expect(result.isError, true);
      expect(result.errorCode, 'PLATFORM_UNSUPPORTED');
    });
  });

  group('NativeCreateCalendarEventConnector', () {
    test('surfaces permission denied responses', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(methodChannel, (_) async {
            return {
              'error': 'calendar_permission_denied',
              'message': 'Calendar permission is required to add this event.',
            };
          });

      final connector = NativeCreateCalendarEventConnector(
        channel: methodChannel,
      );
      final result = await connector.execute({
        'title': 'Bills review',
        'date': '2026-06-20',
        'hour': 19,
      });

      expect(result.isError, true);
      expect(result.errorCode, 'calendar_permission_denied');
    });

    test(
      'returns unavailable error when the platform channel is missing',
      () async {
        final connector = NativeCreateCalendarEventConnector(
          channel: methodChannel,
        );
        final result = await connector.execute({
          'title': 'Bills review',
          'date': '2026-06-20',
          'hour': 19,
        });

        expect(result.isError, true);
        expect(result.errorCode, 'calendar_write_unavailable');
      },
    );
  });
}
