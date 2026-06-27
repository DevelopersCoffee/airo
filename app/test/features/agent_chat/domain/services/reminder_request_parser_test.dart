import 'package:airo_app/features/agent_chat/domain/services/reminder_request_parser.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ReminderRequestParser', () {
    const parser = ReminderRequestParser();

    test('does not overlap calendar schedule lookup requests', () {
      expect(
        parser.shouldSelectReminderSkill('Check my schedule for today'),
        false,
      );
      expect(
        parser.shouldSelectReminderSkill('What meetings do I have tomorrow?'),
        false,
      );
    });

    test('does not treat generic take phrasing as medicine', () {
      expect(
        parser.shouldSelectReminderSkill(
          'Take a look at my money dashboard at 8am',
        ),
        false,
      );
    });

    test('parses custom named daily reminders', () {
      final request = parser.parse(
        prompt: 'Create a reminder called Water plants every day at 7am',
        currentDate: '2026-06-20',
      );

      expect(request, isNotNull);
      expect(request!.title, 'Water plants');
      expect(request.category, ReminderRequestCategory.general);
      expect(request.scheduleType, ReminderScheduleType.dailyTime);
      expect(request.times.single.hour, 7);
      expect(request.repeatDaily, true);
    });

    test(
      'returns additive connector arguments for medicine interval reminders',
      () {
        final request = parser.parse(
          prompt: 'Remind me to take Minoxidil every 12 hours starting at 8am',
          currentDate: '2026-06-20',
        );

        final args = request!.toConnectorArguments();
        expect(args['title'], 'Minoxidil');
        expect(args['category'], 'medicine');
        expect(args['schedule_type'], 'interval_hours');
        expect(args['hour'], 8);
        expect(args['minute'], 0);
        expect(args['times'], [
          {'hour': 8, 'minute': 0},
          {'hour': 20, 'minute': 0},
        ]);
        expect((args['metadata'] as Map)['medicine_name'], 'Minoxidil');
      },
    );

    test('parses due-date reminders that repeat until completed', () {
      final request = parser.parse(
        prompt:
            'Remind me to recharge my electricity bill tomorrow by tomorrow and keep asking until I do it',
        currentDate: '2026-06-20',
      );

      expect(request, isNotNull);
      expect(request!.title, 'Recharge electricity bill');
      expect(request.category, ReminderRequestCategory.billing);
      expect(request.scheduleType, ReminderScheduleType.dueDate);
      expect(request.date, '2026-06-21');
      expect(request.times.single.hour, 9);
      expect(request.repeatDaily, true);
      expect(request.requiresCompletion, true);
      expect(request.followUpPolicy, 'daily_until_done');

      final args = request.toConnectorArguments();
      expect(args['date'], '2026-06-21');
      expect(args['requires_completion'], true);
      expect(args['follow_up_policy'], 'daily_until_done');
    });
  });
}
