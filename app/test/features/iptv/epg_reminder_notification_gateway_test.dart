import 'package:airo_app/features/iptv/epg_reminder_notification_gateway.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
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
}
