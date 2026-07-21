import 'package:airo_app/features/iptv/epg_reminder_notification_gateway.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const notificationsChannel = MethodChannel(
    'dexterous.com/flutter/local_notifications',
  );
  late List<MethodCall> methodCalls;

  setUp(() {
    methodCalls = [];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(notificationsChannel, (call) async {
          methodCalls.add(call);
          switch (call.method) {
            case 'initialize':
              return true;
            case 'requestNotificationsPermission':
            case 'requestPermissions':
              return true;
            case 'zonedSchedule':
            case 'cancel':
              return null;
            default:
              return null;
          }
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(notificationsChannel, null);
    debugDefaultTargetPlatformOverride = null;
  });

  test('notification tap payload routes to the handler', () {
    final routed = <String>[];
    final gateway = FlutterLocalNotificationsEpgReminderGateway(
      onReminderTap: routed.add,
    );

    gateway.handleNotificationPayload('channel-1');
    gateway.handleNotificationPayload(null);
    gateway.handleNotificationPayload('');

    expect(routed, ['channel-1']);
  });

  test('deep link builder encodes channel ids as query parameters', () {
    const channelId = 'news & sports?hd#1';
    final route = epgReminderDeepLinkForChannel(channelId);

    expect(Uri.parse(route).queryParameters['channel'], channelId);
    expect(route, isNot(contains(channelId)));
  });

  test(
    'unavailable platforms report unavailable and do not initialize',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.fuchsia;
      final gateway = FlutterLocalNotificationsEpgReminderGateway();

      expect(gateway.isAvailable, isFalse);
      expect(await gateway.requestPermission(), isFalse);
      expect(methodCalls, isEmpty);
    },
  );

  test('iOS initialization defers permission prompts', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    IOSFlutterLocalNotificationsPlugin.registerWith();
    final gateway = FlutterLocalNotificationsEpgReminderGateway();

    await gateway.initialize();

    expect(methodCalls.map((call) => call.method), ['initialize']);
    final arguments = methodCalls.single.arguments as Map;
    expect(arguments['requestAlertPermission'], isFalse);
    expect(arguments['requestSoundPermission'], isFalse);
    expect(arguments['requestBadgePermission'], isFalse);
  });

  test('schedule initializes timezone and emits payload', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    AndroidFlutterLocalNotificationsPlugin.registerWith();
    final gateway = FlutterLocalNotificationsEpgReminderGateway();

    await gateway.schedule(
      notificationId: 7,
      title: 'Evening Show',
      body: 'Starting now',
      at: DateTime.now().toUtc().add(const Duration(hours: 1)),
      payloadChannelId: 'channel-1',
    );

    expect(gateway.debugIsTimeZoneInitialized, isTrue);
    final zonedScheduleCall = methodCalls.singleWhere(
      (call) => call.method == 'zonedSchedule',
    );
    expect(zonedScheduleCall.arguments, containsPair('id', 7));
    expect(zonedScheduleCall.arguments, containsPair('payload', 'channel-1'));
  });
}
