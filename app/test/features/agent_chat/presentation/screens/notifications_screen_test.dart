import 'package:airo_app/features/agent_chat/application/assistant_model_preferences.dart';
import 'package:airo_app/features/agent_chat/data/services/agent_notification_scheduler.dart';
import 'package:airo_app/features/agent_chat/domain/models/assistant_runtime_ids.dart';
import 'package:airo_app/features/agent_chat/presentation/screens/chat_screen.dart';
import 'package:airo_app/features/agent_chat/presentation/screens/notifications_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('buildNotificationChatPrefill includes reminder context', () {
    final notification = ScheduledAgentNotification(
      id: 1,
      title: 'Medicine reminder',
      message: 'Take vitamin D',
      hour: 8,
      minute: 30,
      repeatDaily: true,
      scheduledAt: DateTime(2026, 6, 29, 8, 30),
      createdAt: DateTime(2026, 6, 29, 7, 0),
    );

    expect(
      buildNotificationChatPrefill(notification),
      'Help me with this reminder: Medicine reminder - Take vitamin D (daily at 8:30 AM).',
    );
  });

  testWidgets('notification card opens chat with a prefilled composer', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'selected_assistant_model_id': geminiNanoAssistantModelId,
    });

    final router = GoRouter(
      initialLocation: '/mind/notifications',
      routes: [
        GoRoute(
          path: '/mind/notifications',
          builder: (context, state) => NotificationsScreen(
            scheduler: _FakeNotificationScheduler(
              notifications: [
                ScheduledAgentNotification(
                  id: 1,
                  title: 'Pay rent',
                  message: 'Check July invoice before paying.',
                  hour: 9,
                  minute: 0,
                  repeatDaily: false,
                  date: '2026-07-01',
                  scheduledAt: DateTime(2026, 7, 1, 9),
                  createdAt: DateTime(2026, 6, 29, 12),
                ),
              ],
            ),
          ),
        ),
        GoRoute(
          path: '/mind/chat',
          builder: (context, state) => ChatScreen(
            enableAiInitialization: false,
            initialDraft: state.uri.queryParameters['prefill'],
          ),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          selectedAssistantModelIdProvider.overrideWith(
            (ref) => _SelectedAssistantModelNotifier(),
          ),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Pay rent'), findsOneWidget);
    await tester.tap(find.text('Open in chat'));
    await tester.pumpAndSettle();

    final input = tester.widget<TextField>(
      find.byKey(const Key('agent_chat_input')),
    );
    expect(
      input.controller?.text,
      'Help me with this reminder: Pay rent - Check July invoice before paying. (on 2026-07-01 at 9:00 AM).',
    );
  });
}

class _SelectedAssistantModelNotifier extends SelectedAssistantModelNotifier {
  _SelectedAssistantModelNotifier() {
    state = geminiNanoAssistantModelId;
  }
}

class _FakeNotificationScheduler implements AgentNotificationSchedulingService {
  _FakeNotificationScheduler({required this._notifications});

  final List<ScheduledAgentNotification> _notifications;

  @override
  Future<void> cancelNotification(int id) async {
    _notifications.removeWhere((notification) => notification.id == id);
  }

  @override
  Future<List<ScheduledAgentNotification>> getScheduledNotifications() async {
    return List<ScheduledAgentNotification>.from(_notifications);
  }

  @override
  Future<ScheduledAgentNotification?> markNotificationComplete(int id) async {
    for (final notification in _notifications) {
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
