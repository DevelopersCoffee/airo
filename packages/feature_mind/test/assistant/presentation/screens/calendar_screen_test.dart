import 'package:feature_mind/src/assistant/presentation/screens/calendar_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:platform_calendar/platform_calendar.dart';

void main() {
  testWidgets('asks for calendar access before listing events', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: CalendarScreen(
          calendar: InMemoryCalendarService(
            permission: CalendarPermissionStatus.notDetermined,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('Needs permission'), findsOneWidget);
    expect(find.byKey(const Key('calendar_allow_access')), findsOneWidget);
    expect(find.text('Team standup'), findsNothing);
  });

  testWidgets('lists today events from every connected calendar', (
    tester,
  ) async {
    final now = DateTime.now();
    final calendar = InMemoryCalendarService(
      calendars: const [
        CalendarAccount(id: 'work', title: 'Work'),
        CalendarAccount(id: 'personal', title: 'Personal'),
      ],
      events: [
        CalendarEvent(
          id: '1',
          title: 'Team standup',
          start: DateTime(now.year, now.month, now.day, 8, 30),
          end: DateTime(now.year, now.month, now.day, 9),
          calendar: 'Work',
        ),
        CalendarEvent(
          id: '2',
          title: 'Lunch',
          start: DateTime(now.year, now.month, now.day, 13),
          end: DateTime(now.year, now.month, now.day, 14),
          calendar: 'Personal',
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(home: CalendarScreen(calendar: calendar)),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('Connected'), findsOneWidget);
    expect(find.text('2 events'), findsOneWidget);
    expect(find.text('Team standup'), findsOneWidget);
    expect(find.text('Lunch'), findsOneWidget);
    expect(find.text('Work'), findsWidgets);
    expect(find.text('Personal'), findsWidgets);
  });

  testWidgets('shows an empty day without inventing events', (tester) async {
    await tester.pumpWidget(
      MaterialApp(home: CalendarScreen(calendar: InMemoryCalendarService())),
    );
    await tester.pumpAndSettle();

    expect(find.text('You have no calendar events today.'), findsOneWidget);
  });
}
