library;

class FlutterLocalNotificationsPlugin {
  Future<bool?> initialize({
    required InitializationSettings settings,
    DidReceiveNotificationResponseCallback? onDidReceiveNotificationResponse,
  }) async => true;

  Future<NotificationAppLaunchDetails?>
  getNotificationAppLaunchDetails() async => null;

  T? resolvePlatformSpecificImplementation<T>() => null;

  Future<void> zonedSchedule({
    required int id,
    required String title,
    required String body,
    required Object scheduledDate,
    required NotificationDetails notificationDetails,
    required AndroidScheduleMode androidScheduleMode,
    DateTimeComponents? matchDateTimeComponents,
    String? payload,
  }) async {}

  Future<void> show({
    required int id,
    required String title,
    required String body,
    required NotificationDetails notificationDetails,
    String? payload,
  }) async {}

  Future<void> cancel({required int id}) async {}
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

  final AndroidNotificationDetails? android;
  final DarwinNotificationDetails? iOS;
  final DarwinNotificationDetails? macOS;
}

enum AndroidScheduleMode { exactAllowWhileIdle, inexactAllowWhileIdle }

enum DateTimeComponents { time }

enum Importance { defaultImportance, high }

enum Priority { defaultPriority, high }
