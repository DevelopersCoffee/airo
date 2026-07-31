import 'package:airo_app/features/iptv/epg_reminder_notification_gateway.dart';
import 'package:feature_iptv/feature_iptv.dart';
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
      onNotificationRoute: routed.add,
    );

    gateway.handleNotificationPayload('/iptv?channel=channel-1');
    gateway.handleNotificationPayload(null);
    gateway.handleNotificationPayload('');

    expect(routed, ['/iptv?channel=channel-1']);
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
    expect(
      Uri.parse(
        zonedScheduleCall.arguments['payload'] as String,
      ).queryParameters['channel'],
      'channel-1',
    );
  });

  test('Android permission request goes through the Android plugin', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    AndroidFlutterLocalNotificationsPlugin.registerWith();
    final gateway = FlutterLocalNotificationsEpgReminderGateway();

    expect(await gateway.requestPermission(), isTrue);
    expect(
      methodCalls.map((call) => call.method),
      containsAllInOrder(['initialize', 'requestNotificationsPermission']),
      reason: 'the plugin has to be initialized before it can be asked',
    );
  });

  test('iOS permission request asks for alert, badge, and sound', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    IOSFlutterLocalNotificationsPlugin.registerWith();
    final gateway = FlutterLocalNotificationsEpgReminderGateway();

    expect(await gateway.requestPermission(), isTrue);

    final request = methodCalls.singleWhere(
      (call) => call.method == 'requestPermissions',
    );
    expect(request.arguments, containsPair('alert', true));
    expect(request.arguments, containsPair('badge', true));
    expect(request.arguments, containsPair('sound', true));
  });

  test('a permission request on a vanished plugin fails closed', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    AndroidFlutterLocalNotificationsPlugin.registerWith();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(notificationsChannel, null);
    final gateway = FlutterLocalNotificationsEpgReminderGateway();

    // initialize() swallows MissingPluginException and flips the gateway to
    // unavailable. Returning "no permission" there would look like a user
    // denial; the caller has to be able to tell the two apart.
    await expectLater(
      gateway.requestPermission(),
      throwsA(isA<EpgReminderGatewayUnavailableException>()),
    );
  });

  test('a plugin that vanishes after initialize fails closed', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    AndroidFlutterLocalNotificationsPlugin.registerWith();
    final gateway = FlutterLocalNotificationsEpgReminderGateway();

    await gateway.initialize();
    expect(gateway.isAvailable, isTrue);

    // Initialization succeeded, so the earlier unavailable guard is already
    // behind us; the failure now surfaces from zonedSchedule itself. A
    // reminder that silently fails to schedule is worse than one that reports
    // it, because the user is told the reminder is set.
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(notificationsChannel, null);

    await expectLater(
      gateway.schedule(
        notificationId: 9,
        title: 'Late Show',
        body: 'Starting now',
        at: DateTime.now().toUtc().add(const Duration(hours: 1)),
        payloadChannelId: 'channel-2',
      ),
      throwsA(isA<EpgReminderGatewayUnavailableException>()),
    );
    expect(gateway.isAvailable, isFalse);
  });

  test('cancel forwards the notification id to the plugin', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    AndroidFlutterLocalNotificationsPlugin.registerWith();
    final gateway = FlutterLocalNotificationsEpgReminderGateway();

    await gateway.cancel(7);

    final cancelCall = methodCalls.singleWhere(
      (call) => call.method == 'cancel',
    );
    expect(cancelCall.arguments, containsPair('id', 7));
  });

  test('missing plugin marks gateway unavailable', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    AndroidFlutterLocalNotificationsPlugin.registerWith();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(notificationsChannel, null);
    final gateway = FlutterLocalNotificationsEpgReminderGateway();

    await expectLater(
      gateway.schedule(
        notificationId: 7,
        title: 'Evening Show',
        body: 'Starting now',
        at: DateTime.now().toUtc().add(const Duration(hours: 1)),
        payloadChannelId: 'channel-1',
      ),
      throwsA(isA<EpgReminderGatewayUnavailableException>()),
    );

    expect(gateway.isAvailable, isFalse);
  });
}
