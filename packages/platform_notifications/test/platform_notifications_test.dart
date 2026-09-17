import 'package:flutter_test/flutter_test.dart';
import 'package:platform_notifications/platform_notifications.dart';

void main() {
  test('platform_notifications shim re-exports airo_notifications contracts correctly', () async {
    final engine = FakeAiroNotificationEngine();

    final alert = AiroAlert(
      id: 'followup_99',
      title: 'Follow up with Rahul',
      body: 'Deployment discussion',
      type: AiroAlertType.task,
      delivery: AiroDeliveryMode.scheduled,
      scheduledAt: DateTime.now().add(const Duration(hours: 1)),
      taskId: 'task_123',
      source: 'aromind',
    );

    await engine.schedule(alert);
    final results = await engine.query(taskId: 'task_123');

    expect(results.length, 1);
    expect(results.single.title, 'Follow up with Rahul');
    expect(results.single.type, AiroAlertType.task);
  });
}
