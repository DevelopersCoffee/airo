import 'dart:async';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

/// ChatScreen wires a [ScheduleNotificationConnector] into its connector
/// registry on init, which eagerly touches `SharedPreferencesAsync()` via
/// airo_notifications' `PreferencesAlertStore`. Any test that mounts
/// ChatScreen (or anything else that reaches that singleton) needs both the
/// legacy and async SharedPreferences platforms mocked, or it throws before
/// the widget it actually cares about ever builds.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  SharedPreferences.setMockInitialValues({});
  SharedPreferencesAsyncPlatform.instance =
      InMemorySharedPreferencesAsync.empty();
  await testMain();
}
