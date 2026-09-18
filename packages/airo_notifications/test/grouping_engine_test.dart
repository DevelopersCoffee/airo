import 'package:airo_notifications/airo_notifications.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final engine = GroupingEngine();

  test('replace grouping strategy replaces previous notification in same group', () async {
    final alert1 = AiroAlert(
      id: 'dl_1',
      title: 'Downloading Movie A',
      body: '43%',
      groupId: 'download_progress',
    );
    final alert2 = AiroAlert(
      id: 'dl_2',
      title: 'Downloading Movie A',
      body: '44%',
      groupId: 'download_progress',
    );

    const group = AiroNotificationGroup(
      id: 'download_progress',
      strategy: AiroGroupingStrategy.replace,
    );

    final result = await engine.applyGrouping(
      existingAlerts: [alert1],
      newAlert: alert2,
      group: group,
    );

    expect(result.length, 1);
    expect(result.single.id, 'dl_2');
    expect(result.single.body, '44%');
  });

  test('summary grouping strategy aggregates multiple items into a single summary', () async {
    final alert1 = AiroAlert(id: 'dl_1', title: 'Movie A', groupId: 'downloads');
    final alert2 = AiroAlert(id: 'dl_2', title: 'Movie B', groupId: 'downloads');
    final alert3 = AiroAlert(id: 'dl_3', title: 'Movie C', groupId: 'downloads');

    const group = AiroNotificationGroup(
      id: 'downloads',
      strategy: AiroGroupingStrategy.summary,
      summaryTitle: '3 downloads completed',
    );

    final result = await engine.applyGrouping(
      existingAlerts: [alert1, alert2],
      newAlert: alert3,
      group: group,
    );

    expect(result.length, 1);
    expect(result.single.title, '3 downloads completed');
    expect(result.single.metadata['is_summary'], true);
  });
}
