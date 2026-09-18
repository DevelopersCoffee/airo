// ignore_for_file: avoid_print

import 'package:airo_notifications/airo_notifications.dart';

void main() async {
  final engine = AiroNotifications.engine;
  await engine.initialize(
    onAction: (event) {
      print('Notification action received: ${event.action} for ${event.alertId}');
    },
  );

  final alert = AiroAlert(
    id: 'followup_123',
    type: AiroAlertType.task,
    delivery: AiroDeliveryMode.scheduled,
    priority: AiroPriority.high,
    title: 'Follow up with Rahul',
    body: 'Follow up about the deployment',
    scheduledAt: DateTime.now().add(const Duration(hours: 12)),
    taskId: 'task_456',
    source: 'aromind',
  );

  await engine.schedule(alert);
  print('Scheduled alert: ${alert.title}');

  final scheduledAlerts = await engine.query(includeDelivered: false);
  print('Total scheduled: ${scheduledAlerts.length}');
}
