import 'package:airo_notifications/airo_notifications.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('FakeAiroNotificationEngine executes show, schedule, snooze, and markCompleted', () async {
    final engine = FakeAiroNotificationEngine();

    final alert = AiroAlert(
      id: 'task_88',
      title: 'Meeting with Client',
      type: AiroAlertType.task,
      delivery: AiroDeliveryMode.scheduled,
      scheduledAt: DateTime.now().add(const Duration(hours: 2)),
      taskId: 'task_88',
    );

    await engine.schedule(alert);
    expect(engine.scheduledAlerts.length, 1);

    final pending = await engine.query(status: AiroAlertStatus.pending);
    expect(pending.length, 1);

    await engine.snooze('task_88', const Duration(minutes: 30));
    final snoozed = await engine.query(status: AiroAlertStatus.snoozed);
    expect(snoozed.length, 1);

    await engine.markCompleted('task_88');
    final completed = await engine.query(status: AiroAlertStatus.completed);
    expect(completed.length, 1);
  });
}
