import 'package:feature_iptv/feature_iptv.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

String epgReminderDeepLinkForChannel(String channelId) {
  return Uri(path: '/iptv', queryParameters: {'channel': channelId}).toString();
}

/// App-level local notification gateway for EPG reminders.
class FlutterLocalNotificationsEpgReminderGateway
    implements EpgReminderNotificationGateway {
  FlutterLocalNotificationsEpgReminderGateway({this.onNotificationRoute});

  static const String _notificationChannelId = 'epg_reminders';

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  final void Function(String location)? onNotificationRoute;
  bool _initialized = false;
  bool _timeZoneInitialized = false;
  bool _pluginUnavailable = false;

  @override
  bool get isAvailable =>
      !kIsWeb &&
      !_pluginUnavailable &&
      (defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.android);

  @visibleForTesting
  bool get debugIsTimeZoneInitialized => _timeZoneInitialized;

  Future<void> initialize() async {
    if (_initialized || !isAvailable) return;

    const settings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(
        requestAlertPermission: false,
        requestSoundPermission: false,
        requestBadgePermission: false,
      ),
    );
    try {
      await _plugin.initialize(
        settings: settings,
        onDidReceiveNotificationResponse: (response) {
          handleNotificationPayload(response.payload);
        },
      );
    } on MissingPluginException {
      _pluginUnavailable = true;
      return;
    }
    _initialized = true;
  }

  @visibleForTesting
  void handleNotificationPayload(String? payload) {
    if (payload == null || payload.isEmpty) return;
    onNotificationRoute?.call(payload);
  }

  @override
  Future<bool> requestPermission() async {
    if (!isAvailable) return false;
    await initialize();
    if (!isAvailable) throw const EpgReminderGatewayUnavailableException();

    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (android != null) {
      return await android.requestNotificationsPermission() ?? false;
    }

    final ios = _plugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >();
    if (ios != null) {
      return await ios.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          ) ??
          false;
    }

    return false;
  }

  @override
  Future<void> schedule({
    required int notificationId,
    required String title,
    required String body,
    required DateTime at,
    required String payloadChannelId,
  }) async {
    await initialize();
    if (!isAvailable) throw const EpgReminderGatewayUnavailableException();
    _configureLocalTimeZone();
    try {
      await _plugin.zonedSchedule(
        id: notificationId,
        title: title,
        body: body,
        scheduledDate: tz.TZDateTime.from(at, tz.local),
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            _notificationChannelId,
            'Program Reminders',
            channelDescription: 'Reminders for upcoming live programs',
            importance: Importance.high,
            priority: Priority.high,
          ),
          iOS: DarwinNotificationDetails(),
        ),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        payload: epgReminderDeepLinkForChannel(payloadChannelId),
      );
    } on MissingPluginException {
      _pluginUnavailable = true;
      throw const EpgReminderGatewayUnavailableException();
    }
  }

  @override
  Future<void> cancel(int notificationId) {
    return _plugin.cancel(id: notificationId);
  }

  void _configureLocalTimeZone() {
    if (_timeZoneInitialized) return;
    tz_data.initializeTimeZones();
    final now = DateTime.now();
    final abbreviation = now.timeZoneName.isEmpty ? 'LOCAL' : now.timeZoneName;
    tz.setLocalLocation(
      tz.Location('local', [tz.minTime], [0], [
        tz.TimeZone(
          now.timeZoneOffset,
          isDst: abbreviation.toUpperCase().contains('DT'),
          abbreviation: abbreviation,
        ),
      ]),
    );
    _timeZoneInitialized = true;
  }
}
