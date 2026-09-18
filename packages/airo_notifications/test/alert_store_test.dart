import 'package:airo_notifications/airo_notifications.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('InMemoryAlertStore saves, queries, updates status, and deletes alerts', () async {
    final store = InMemoryAlertStore();

    final alert1 = AiroAlert(
      id: 'alert_1',
      title: 'Task 1',
      type: AiroAlertType.task,
      source: 'aromind',
    );
    final alert2 = AiroAlert(
      id: 'alert_2',
      title: 'Reminder 1',
      type: AiroAlertType.reminder,
      source: 'epg',
    );

    await store.save(alert1);
    await store.save(alert2);

    final tasks = await store.query(type: AiroAlertType.task);
    expect(tasks.length, 1);
    expect(tasks.single.id, 'alert_1');

    await store.updateStatus('alert_1', AiroAlertStatus.snoozed);
    final updated = await store.get('alert_1');
    expect(updated?.status, AiroAlertStatus.snoozed);

    await store.delete('alert_1');
    final remaining = await store.query(includeDelivered: true);
    expect(remaining.length, 1);
    expect(remaining.single.id, 'alert_2');
  });
}
