library;

class FlutterLocalNotificationsPlugin {
  Future<bool?> initialize(
    InitializationSettings initializationSettings, {
    InitializationSettings? settings,
    DidReceiveNotificationResponseCallback? onDidReceiveNotificationResponse,
  }) async => true;

  Future<NotificationAppLaunchDetails?>
  getNotificationAppLaunchDetails() async => null;

  T? resolvePlatformSpecificImplementation<T>() => null;

  Future<void> zonedSchedule(
    int id,
    String? title,
    String? body,
    Object scheduledDate,
    NotificationDetails notificationDetails, {
    AndroidScheduleMode? androidScheduleMode,
    UILocalNotificationDateInterpretation? uiLocalNotificationDateInterpretation,
    DateTimeComponents? matchDateTimeComponents,
    String? payload,
  }) async {}

  Future<void> show(
    int id,
    String? title,
    String? body,
    NotificationDetails? notificationDetails, {
    String? payload,
  }) async {}

  Future<void> cancel(
    int id, {
    String? tag,
  }) async {}
}

typedef DidReceiveNotificationResponseCallback =
    void Function(NotificationResponse response);

class NotificationAppLaunchDetails {
  const NotificationAppLaunchDetails({
    required this.didNotificationLaunchApp,
    this.notificationResponse,
  });

  final bool didNotificationLaunchApp;
  final NotificationResponse? notificationResponse;
}

class NotificationResponse {
  const NotificationResponse({this.payload});

  final String? payload;
}

class AndroidFlutterLocalNotificationsPlugin {
  Future<bool?> requestNotificationsPermission() async => false;
}

class IOSFlutterLocalNotificationsPlugin {
  Future<bool?> requestPermissions({
    bool alert = false,
    bool badge = false,
    bool sound = false,
  }) async => false;
}

class MacOSFlutterLocalNotificationsPlugin {
  Future<bool?> requestPermissions({
    bool alert = false,
    bool badge = false,
    bool sound = false,
  }) async => false;
}

class AndroidInitializationSettings {
  const AndroidInitializationSettings(this.defaultIcon);

  final String defaultIcon;
}

class DarwinInitializationSettings {
  const DarwinInitializationSettings({
    this.requestAlertPermission = true,
    this.requestBadgePermission = true,
    this.requestSoundPermission = true,
  });

  final bool requestAlertPermission;
  final bool requestBadgePermission;
  final bool requestSoundPermission;
}

class InitializationSettings {
  const InitializationSettings({this.android, this.iOS, this.macOS});

  final AndroidInitializationSettings? android;
  final DarwinInitializationSettings? iOS;
  final DarwinInitializationSettings? macOS;
}

class AndroidNotificationDetails {
  const AndroidNotificationDetails(
    this.channelId,
    this.channelName, {
    this.channelDescription,
    this.importance = Importance.defaultImportance,
    this.priority = Priority.defaultPriority,
  });

  final String channelId;
  final String channelName;
  final String? channelDescription;
  final Importance importance;
  final Priority priority;
}

class DarwinNotificationDetails {
  const DarwinNotificationDetails();
}

class NotificationDetails {
  const NotificationDetails({this.android, this.iOS, this.macOS});

  final AndroidInitializationSettings? android;
  final DarwinInitializationSettings? iOS;
  final DarwinInitializationSettings? macOS;
}

enum AndroidScheduleMode { exactAllowWhileIdle, inexactAllowWhileIdle }

enum UILocalNotificationDateInterpretation { absoluteTime, wallClockTime }

enum DateTimeComponents { time }

enum Importance { defaultImportance, high }

enum Priority { defaultPriority, high }
