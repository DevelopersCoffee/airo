import 'dart:convert';

import 'package:airo_app/features/agent_chat/data/services/agent_notification_scheduler.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:shared_preferences_platform_interface/types.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const notificationsChannel = MethodChannel(
    'dexterous.com/flutter/local_notifications',
  );

  late SharedPreferencesAsync preferences;
  late LocalAgentNotificationScheduler scheduler;
  late List<MethodCall> methodCalls;

  setUp(() async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    AndroidFlutterLocalNotificationsPlugin.registerWith();
    SharedPreferences.setMockInitialValues({});
    SharedPreferencesAsyncPlatform.instance =
        _InMemoryPreferencesAsyncPlatform();
    preferences = SharedPreferencesAsync();
    await preferences.clear();
    methodCalls = [];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(notificationsChannel, (call) async {
          methodCalls.add(call);
          switch (call.method) {
            case 'initialize':
              return true;
            case 'requestNotificationsPermission':
              return true;
            case 'zonedSchedule':
            case 'cancel':
              return null;
            default:
              return null;
          }
        });
    scheduler = LocalAgentNotificationScheduler(
      notificationsPlugin: FlutterLocalNotificationsPlugin(),
      preferences: preferences,
    );
  });

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(notificationsChannel, null);
    debugDefaultTargetPlatformOverride = null;
  });

  test(
    'suppresses duplicate schedules and emits stable deep-link payloads',
    () async {
      const request = ScheduleAgentNotificationRequest(
        title: 'Download model',
        message: 'Open the downloads screen for progress updates.',
        hour: 9,
        minute: 30,
        repeatDaily: true,
        category: 'downloads',
        scheduleType: 'progress',
        metadata: {
          'deep_link': '/mind/notifications?tab=downloads',
          'download_id': 'gemma-3n-e4b-it',
        },
      );

      final first = await scheduler.scheduleNotification(request);
      final duplicate = await scheduler.scheduleNotification(request);

      expect(duplicate.id, first.id);
      expect(await scheduler.getScheduledNotifications(), hasLength(1));

      final zonedCalls = methodCalls.where(
        (call) => call.method == 'zonedSchedule',
      );
      expect(zonedCalls, hasLength(1));

      final payload =
          jsonDecode((zonedCalls.single.arguments as Map)['payload'] as String)
              as Map<String, dynamic>;
      expect(payload['version'], 1);
      expect(payload['notification_id'], first.id);
      expect(payload['category'], 'downloads');
      expect(payload['schedule_type'], 'progress');
      expect(payload['deep_link'], '/mind/notifications?tab=downloads');
      expect(
        payload['metadata'],
        containsPair('download_id', 'gemma-3n-e4b-it'),
      );
    },
  );

  test('marks completion once and cancels daily follow-up reminders', () async {
    final scheduled = await scheduler.scheduleNotification(
      const ScheduleAgentNotificationRequest(
        title: 'Finish recording',
        message: 'Return to the recorder and complete the upload.',
        hour: 18,
        minute: 0,
        repeatDaily: true,
        category: 'recording',
        scheduleType: 'follow_up',
        requiresCompletion: true,
        followUpPolicy: 'daily_until_done',
        metadata: {'deep_link': '/mind/recordings'},
      ),
    );

    final completed = await scheduler.markNotificationComplete(scheduled.id);
    final repeated = await scheduler.markNotificationComplete(scheduled.id);

    expect(completed, isNotNull);
    expect(completed!.streakCount, 1);
    expect(completed.points, 10);
    expect(completed.completedDates, hasLength(1));
    expect(repeated!.streakCount, 1);
    expect(repeated.points, 10);

    final cancelCalls = methodCalls.where((call) => call.method == 'cancel');
    expect(cancelCalls, hasLength(1));
    expect(cancelCalls.single.arguments, containsPair('id', scheduled.id));
  });

  test('recovers stored notifications in scheduled order', () async {
    await preferences.setString(
      'agent_scheduled_notifications_v1',
      jsonEncode([
        _notificationJson(
          id: 2,
          title: 'Later',
          hour: 22,
          minute: 15,
          scheduledAt: DateTime(2026, 6, 30, 22, 15),
        ),
        _notificationJson(
          id: 1,
          title: 'Earlier',
          hour: 8,
          minute: 45,
          scheduledAt: DateTime(2026, 6, 30, 8, 45),
        ),
      ]),
    );

    final notifications = await scheduler.getScheduledNotifications();

    expect(notifications.map((item) => item.id).toList(), [1, 2]);
    expect(notifications.first.title, 'Earlier');
    expect(notifications.last.title, 'Later');
  });
}

Map<String, dynamic> _notificationJson({
  required int id,
  required String title,
  required int hour,
  required int minute,
  required DateTime scheduledAt,
}) {
  return {
    'id': id,
    'title': title,
    'message': '$title body',
    'hour': hour,
    'minute': minute,
    'repeat_daily': true,
    'category': 'general',
    'schedule_type': 'daily_time',
    'requires_completion': false,
    'follow_up_policy': 'none',
    'completed_dates': const <String>[],
    'streak_count': 0,
    'points': 0,
    'scheduled_at': scheduledAt.toIso8601String(),
    'created_at': DateTime(2026, 6, 29, 12).toIso8601String(),
  };
}

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
