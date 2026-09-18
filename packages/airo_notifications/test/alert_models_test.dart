import 'package:airo_notifications/airo_notifications.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('AiroAlert serializes and deserializes cleanly via JSON', () {
    final alert = AiroAlert(
      id: 'task_101',
      title: 'Submit Expense Report',
      body: 'Monthly travel expenses',
      type: AiroAlertType.task,
      delivery: AiroDeliveryMode.scheduled,
      priority: AiroPriority.high,
      scheduledAt: DateTime.parse('2026-09-17T08:00:00.000Z'),
      timezone: 'Asia/Kolkata',
      groupId: 'expenses',
      taskId: 'task_99',
      source: 'aromind',
      metadata: const {'amount': 1500, 'currency': 'INR'},
    );

    final json = alert.toJson();
    final restored = AiroAlert.fromJson(json);

    expect(restored.id, alert.id);
    expect(restored.title, alert.title);
    expect(restored.type, AiroAlertType.task);
    expect(restored.delivery, AiroDeliveryMode.scheduled);
    expect(restored.priority, AiroPriority.high);
    expect(restored.scheduledAt, alert.scheduledAt);
    expect(restored.timezone, 'Asia/Kolkata');
    expect(restored.groupId, 'expenses');
    expect(restored.taskId, 'task_99');
    expect(restored.source, 'aromind');
    expect(restored.metadata['amount'], 1500);
  });
}
