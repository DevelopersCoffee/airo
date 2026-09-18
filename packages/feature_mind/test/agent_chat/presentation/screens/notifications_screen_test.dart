import 'package:feature_mind/src/host/assistant_host_adapter.dart';
import 'package:feature_mind/src/agent_chat/application/assistant_model_preferences.dart';
import 'package:feature_mind/src/agent_chat/data/services/agent_notification_scheduler.dart';
import 'package:feature_mind/src/agent_chat/domain/models/assistant_runtime_ids.dart';
import 'package:feature_mind/src/agent_chat/presentation/screens/chat_screen.dart';
import 'package:feature_mind/src/agent_chat/presentation/screens/notifications_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:shared_preferences_platform_interface/types.dart';
import 'package:feature_mind/src/agent_chat/presentation/screens/model_library_screen.dart';
import '../../../support/gemini_nano_channel.dart';
import '../../../support/fake_assistant_host_adapter.dart';

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
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(1200, 1000);
    addTearDown(() {
      tester.view.resetDevicePixelRatio();
      tester.view.resetPhysicalSize();
    });

    stubGeminiNanoChannel();
    SharedPreferences.setMockInitialValues({
      'selected_assistant_model_id': geminiNanoAssistantModelId,
    });
    SharedPreferencesAsyncPlatform.instance = _InMemoryPreferencesAsyncPlatform();

    final router = GoRouter(
      initialLocation: '/assistant/notifications',
      routes: [
        GoRoute(
          path: '/assistant/notifications',
          builder: (context, state) => NotificationsScreen(
            permissionService: _FakeNotificationPermissionService(
              status: AgentNotificationPermissionStatus.enabled,
              grantOnRequest: true,
            ),
            scheduler: _FakeNotificationScheduler([
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
            ]),
          ),
        ),
        GoRoute(
          path: '/assistant/chat',
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
          assistantHostAdapterProvider.overrideWithValue(
            FakeAssistantHostAdapter(),
          ),
          assistantModelLibraryProvider.overrideWith(
            (ref) async => _chatLibraryState,
          ),
          selectedAssistantModelIdProvider.overrideWith(
            (ref) => _SelectedAssistantModelNotifier(),
          ),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Pay rent'), findsOneWidget);
    await tester.ensureVisible(find.text('Open in chat'));
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
          permissionService: _FakeNotificationPermissionService(
            status: AgentNotificationPermissionStatus.enabled,
            grantOnRequest: true,
          ),
          initialCategory: 'recording',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Recording Notifications (1)'), findsOneWidget);
    expect(find.text('Recording reminder'), findsOneWidget);
    expect(find.text('Download reminder'), findsNothing);
  });

  testWidgets('friendly permission card requests access and hides on grant', (
    tester,
  ) async {
    final permissionService = _FakeNotificationPermissionService(
      status: AgentNotificationPermissionStatus.disabled,
      grantOnRequest: true,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: NotificationsScreen(
          scheduler: _FakeNotificationScheduler([]),
          permissionService: permissionService,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Let Airo ring the tiny bell?'), findsOneWidget);
    expect(find.text('Yes, keep me posted'), findsOneWidget);

    await tester.tap(find.text('Yes, keep me posted'));
    await tester.pumpAndSettle();

    expect(permissionService.requestCount, 1);
    expect(find.text('Let Airo ring the tiny bell?'), findsNothing);
    expect(
      find.text('Bell acquired. Airo can now keep you posted.'),
      findsOneWidget,
    );
  });

  testWidgets('denial keeps in-app updates and the retry path available', (
    tester,
  ) async {
    final permissionService = _FakeNotificationPermissionService(
      status: AgentNotificationPermissionStatus.disabled,
      grantOnRequest: false,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: NotificationsScreen(
          scheduler: _FakeNotificationScheduler([]),
          permissionService: permissionService,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Yes, keep me posted'));
    await tester.pumpAndSettle();

    expect(permissionService.requestCount, 1);
    expect(find.text('Let Airo ring the tiny bell?'), findsOneWidget);
    expect(
      find.text('No worries — Airo will keep updates inside the app.'),
      findsOneWidget,
    );
  });

  testWidgets('enabled and unavailable states do not show a permission card', (
    tester,
  ) async {
    for (final status in [
      AgentNotificationPermissionStatus.enabled,
      AgentNotificationPermissionStatus.unavailable,
    ]) {
      await tester.pumpWidget(
        MaterialApp(
          home: NotificationsScreen(
            scheduler: _FakeNotificationScheduler([]),
            permissionService: _FakeNotificationPermissionService(
              status: status,
              grantOnRequest: false,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Let Airo ring the tiny bell?'), findsNothing);
    }
  });

  testWidgets('permission card remains usable at 200 percent text scale', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(2)),
          child: NotificationsScreen(
            scheduler: _FakeNotificationScheduler([]),
            permissionService: _FakeNotificationPermissionService(
              status: AgentNotificationPermissionStatus.disabled,
              grantOnRequest: false,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Yes, keep me posted'), findsOneWidget);
  });
}

class _SelectedAssistantModelNotifier extends SelectedAssistantModelNotifier {
  _SelectedAssistantModelNotifier() {
    state = geminiNanoAssistantModelId;
  }
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

final class _FakeNotificationPermissionService
    implements AgentNotificationPermissionService {
  _FakeNotificationPermissionService({
    required this.status,
    required this.grantOnRequest,
  });

  AgentNotificationPermissionStatus status;
  final bool grantOnRequest;
  int requestCount = 0;

  @override
  Future<AgentNotificationPermissionStatus>
  notificationPermissionStatus() async => status;

  @override
  Future<bool> requestNotificationPermission() async {
    requestCount += 1;
    if (grantOnRequest) {
      status = AgentNotificationPermissionStatus.enabled;
    }
    return grantOnRequest;
  }
}

const _chatCandidate = AssistantModelCandidate(
  id: geminiNanoAssistantModelId,
  name: 'Gemini Nano',
  runtime: 'AICore on-device',
  description: 'System runtime',
  bestFor: [AssistantTask.chat],
  tags: ['Local'],
  privacyLabel: 'Prompt stays on device',
  sizeLabel: 'System managed',
  available: true,
  actionLabel: 'Start',
  local: true,
);

const _chatLibraryState = AssistantModelLibraryState(
  task: AssistantTask.chat,
  deviceLabel: 'Google Pixel 9',
  platformLabel: 'ANDROID',
  candidates: [_chatCandidate],
  recommended: _chatCandidate,
  defaultPackages: {},
);

final class _InMemoryPreferencesAsyncPlatform
    extends SharedPreferencesAsyncPlatform {
  final Map<String, Object> _values = {};

  @override
  Future<void> clear(
    ClearPreferencesParameters parameters,
    SharedPreferencesOptions options,
  ) async {
    final allowList = parameters.filter.allowList;
    if (allowList == null) {
      _values.clear();
      return;
    }
    _values.removeWhere((key, _) => allowList.contains(key));
  }

  @override
  Future<bool?> getBool(String key, SharedPreferencesOptions options) async {
    return _values[key] as bool?;
  }

  @override
  Future<double?> getDouble(
    String key,
    SharedPreferencesOptions options,
  ) async {
    return _values[key] as double?;
  }

  @override
  Future<int?> getInt(String key, SharedPreferencesOptions options) async {
    return _values[key] as int?;
  }

  @override
  Future<Map<String, Object>> getPreferences(
    GetPreferencesParameters parameters,
    SharedPreferencesOptions options,
  ) async {
    final allowList = parameters.filter.allowList;
    if (allowList == null) {
      return Map<String, Object>.from(_values);
    }
    return Map<String, Object>.fromEntries(
      _values.entries.where((entry) => allowList.contains(entry.key)),
    );
  }

  @override
  Future<Set<String>> getKeys(
    GetPreferencesParameters parameters,
    SharedPreferencesOptions options,
  ) async {
    return (await getPreferences(parameters, options)).keys.toSet();
  }

  @override
  Future<String?> getString(
    String key,
    SharedPreferencesOptions options,
  ) async {
    return _values[key] as String?;
  }

  @override
  Future<List<String>?> getStringList(
    String key,
    SharedPreferencesOptions options,
  ) async {
    return (_values[key] as List<Object?>?)?.cast<String>();
  }

  @override
  Future<void> setBool(
    String key,
    bool value,
    SharedPreferencesOptions options,
  ) async {
    _values[key] = value;
  }

  @override
  Future<void> setDouble(
    String key,
    double value,
    SharedPreferencesOptions options,
  ) async {
    _values[key] = value;
  }

  @override
  Future<void> setInt(
    String key,
    int value,
    SharedPreferencesOptions options,
  ) async {
    _values[key] = value;
  }

  @override
  Future<void> setString(
    String key,
    String value,
    SharedPreferencesOptions options,
  ) async {
    _values[key] = value;
  }

  @override
  Future<void> setStringList(
    String key,
    List<String> value,
    SharedPreferencesOptions options,
  ) async {
    _values[key] = List<String>.from(value);
  }
}
