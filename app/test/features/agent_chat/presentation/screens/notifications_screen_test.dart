import 'package:airo_app/features/agent_chat/data/services/agent_notification_scheduler.dart';
import 'package:airo_app/features/agent_chat/presentation/screens/notifications_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('filters notifications by initial category route state', (
    tester,
  ) async {
    final scheduler = _FakeNotificationScheduler([
      ScheduledAgentNotification(
        id: 1,
        title: 'Recording reminder',
        message: 'Finish the upload.',
        hour: 9,
        minute: 0,
        repeatDaily: true,
        scheduledAt: DateTime(2026, 6, 30, 9),
        createdAt: DateTime(2026, 6, 29, 12),
        category: 'recording',
      ),
      ScheduledAgentNotification(
        id: 2,
        title: 'Download reminder',
        message: 'Check model download progress.',
        hour: 10,
        minute: 0,
        repeatDaily: true,
        scheduledAt: DateTime(2026, 6, 30, 10),
        createdAt: DateTime(2026, 6, 29, 12),
        category: 'downloads',
      ),
    ]);

    await tester.pumpWidget(
      MaterialApp(
        home: NotificationsScreen(
          scheduler: scheduler,
          initialCategory: 'recording',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Recording Notifications (1)'), findsOneWidget);
    expect(find.text('Recording reminder'), findsOneWidget);
    expect(find.text('Download reminder'), findsNothing);
  });
}

final class _FakeNotificationScheduler
    implements AgentNotificationSchedulingService {
  _FakeNotificationScheduler(this.notifications);

  final List<ScheduledAgentNotification> notifications;

  @override
  Future<void> cancelNotification(int id) async {
    notifications.removeWhere((notification) => notification.id == id);
  }

  @override
  Future<List<ScheduledAgentNotification>> getScheduledNotifications() async {
    return List<ScheduledAgentNotification>.from(notifications);
  }

  @override
  Future<ScheduledAgentNotification?> markNotificationComplete(int id) async {
    for (final notification in notifications) {
      if (notification.id == id) {
        return notification;
      }
    }
    return null;
  }

  @override
  Future<ScheduledAgentNotification> scheduleNotification(
    ScheduleAgentNotificationRequest request,
  ) {
    throw UnimplementedError();
  }
}
