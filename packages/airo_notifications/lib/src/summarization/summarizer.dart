import '../models/alert.dart';
import '../models/group.dart';

class AiroNotificationSummary {
  const AiroNotificationSummary({
    required this.title,
    required this.body,
    required this.count,
    this.groupId,
  });

  final String title;
  final String body;
  final int count;
  final String? groupId;
}

abstract interface class AiroNotificationSummarizer {
  Future<AiroNotificationSummary> summarize(
    List<AiroAlert> alerts, {
    AiroNotificationGroup? group,
  });
}

class DefaultDeterministicSummarizer implements AiroNotificationSummarizer {
  const DefaultDeterministicSummarizer();

  @override
  Future<AiroNotificationSummary> summarize(
    List<AiroAlert> alerts, {
    AiroNotificationGroup? group,
  }) async {
    if (alerts.isEmpty) {
      return const AiroNotificationSummary(
        title: 'Notifications',
        body: 'No new updates',
        count: 0,
      );
    }

    if (alerts.length == 1) {
      final item = alerts.single;
      return AiroNotificationSummary(
        title: item.title,
        body: item.body ?? '',
        count: 1,
        groupId: item.groupId,
      );
    }

    final customTitle = group?.summaryTitle;
    final title = customTitle ?? '${alerts.length} new updates';
    final body = alerts.map((a) => a.title).take(4).join(', ');

    return AiroNotificationSummary(
      title: title,
      body: body,
      count: alerts.length,
      groupId: group?.id,
    );
  }
}
