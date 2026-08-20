import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:platform_calendar/platform_calendar.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final standup = CalendarEvent(
    id: '1',
    title: 'Team standup',
    start: DateTime(2026, 8, 20, 10),
    end: DateTime(2026, 8, 20, 10, 30),
    calendar: 'Work',
    calendarId: 'work',
  );
  final doctor = CalendarEvent(
    id: '2',
    title: 'Doctor visit',
    start: DateTime(2026, 8, 20, 15),
    end: DateTime(2026, 8, 20, 15, 45),
    calendar: 'Personal',
    calendarId: 'personal',
  );

  group('InMemoryCalendarService', () {
    test('lists events from every connected calendar for a day', () async {
      final calendar = InMemoryCalendarService(
        calendars: const [
          CalendarAccount(id: 'work', title: 'Work', account: 'Google'),
          CalendarAccount(id: 'personal', title: 'Personal', account: 'iCloud'),
        ],
        events: [standup, doctor],
      );

      final events = await calendar.getEventsForDay(DateTime(2026, 8, 20));

      expect(events, hasLength(2));
      expect(events.map((event) => event.calendar), ['Work', 'Personal']);
    });

    test('rejects inverted ranges and oversized maxResults', () {
      expect(
        () => CalendarQuery(
          start: DateTime(2026, 8, 21),
          end: DateTime(2026, 8, 20),
        ).validate(),
        throwsA(
          isA<CalendarException>().having(
            (error) => error.code,
            'code',
            CalendarFailureCode.invalidArgument,
          ),
        ),
      );
      expect(
        () => CalendarQuery(
          start: DateTime(2026, 8, 20),
          end: DateTime(2026, 8, 21),
          maxResults: 0,
        ).validate(),
        throwsA(isA<CalendarException>()),
      );
    });

    test('does not fabricate events before permission is granted', () async {
      final calendar = InMemoryCalendarService(
        permission: CalendarPermissionStatus.notDetermined,
        events: [standup],
      );

      expect(
        () => calendar.getEventsForDay(DateTime(2026, 8, 20)),
        throwsA(
          isA<CalendarException>().having(
            (error) => error.code,
            'code',
            CalendarFailureCode.permissionRequired,
          ),
        ),
      );

      await calendar.requestPermission();
      expect(
        (await calendar.getEventsForDay(DateTime(2026, 8, 20))).single.title,
        'Team standup',
      );
    });

    test('returns next event and free/busy gaps', () async {
      final calendar = InMemoryCalendarService(events: [standup, doctor]);
      final next = await calendar.getNextEvent(from: DateTime(2026, 8, 20, 9));
      expect(next?.title, 'Team standup');

      final freeBusy = await calendar.getFreeBusy(
        CalendarDateTimeRange(
          start: DateTime(2026, 8, 20, 9),
          end: DateTime(2026, 8, 20, 16),
        ),
      );
      expect(freeBusy.busy, hasLength(2));
      expect(freeBusy.free, isNotEmpty);
    });

    test(
      'filters events by search text without requiring a calendar name',
      () async {
        final calendar = InMemoryCalendarService(events: [standup, doctor]);
        final found = await calendar.getEvents(
          CalendarQuery(
            start: DateTime(2026, 8, 20),
            end: DateTime(2026, 8, 21),
            searchText: 'doctor',
          ),
        );
        expect(found.single.title, 'Doctor visit');
      },
    );
  });

  group('UnsupportedCalendarService', () {
    test('never returns fake events', () async {
      const calendar = UnsupportedCalendarService(adapterName: 'linux');
      final permission = await calendar.permissionStatus();
      expect(permission.status, CalendarPermissionStatus.unsupported);
      expect(
        () => calendar.getEventsForDay(DateTime(2026, 8, 20)),
        throwsA(
          isA<CalendarException>().having(
            (error) => error.code,
            'code',
            CalendarFailureCode.platformUnsupported,
          ),
        ),
      );
    });
  });

  group('MethodChannelCalendarService', () {
    const channel = MethodChannel(calendarMethodChannelName);

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    test('diagnostic logs omit event titles', () {
      final logs = <String>[];
      final previous = debugPrint;
      debugPrint = (String? message, {int? wrapWidth}) {
        if (message != null) logs.add(message);
      };
      addTearDown(() => debugPrint = previous);

      logCalendarDiagnostic(
        operation: 'getEvents',
        eventCount: 2,
        durationMs: 8,
        adapter: 'in_memory',
      );

      final combined = logs.join('\n');
      expect(combined, contains('event_count=2'));
      expect(combined, contains('duration=8ms'));
      expect(combined, isNot(contains('standup')));
      expect(combined, isNot(contains('title')));
    });

    test('maps native events and does not log titles', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            expect(call.method, 'getEvents');
            return {
              'events': [standup.toJson()],
              'adapter': 'android',
              'duration_ms': 12,
            };
          });

      final calendar = MethodChannelCalendarService(channel: channel);
      final events = await calendar.getEventsForDay(DateTime(2026, 8, 20));
      expect(events.single.title, 'Team standup');
    });

    test('maps missing plugin to PLATFORM_UNSUPPORTED', () async {
      final calendar = MethodChannelCalendarService(channel: channel);
      expect(
        () => calendar.getEventsForDay(DateTime(2026, 8, 20)),
        throwsA(
          isA<CalendarException>().having(
            (error) => error.code,
            'code',
            CalendarFailureCode.platformUnsupported,
          ),
        ),
      );
    });
  });

  test('reserved providers stay unimplemented', () async {
    expect(
      () => const GoogleCalendarProvider().listCalendars(),
      throwsA(isA<CalendarException>()),
    );
    expect(
      () => const OutlookCalendarProvider().listCalendars(),
      throwsA(isA<CalendarException>()),
    );
    expect(
      () => const CalDavProvider().listCalendars(),
      throwsA(isA<CalendarException>()),
    );
  });
}
