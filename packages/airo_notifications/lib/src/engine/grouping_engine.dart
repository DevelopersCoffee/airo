import '../models/alert.dart';
import '../models/group.dart';
import '../summarization/summarizer.dart';

class GroupingEngine {
  GroupingEngine({AiroNotificationSummarizer? summarizer})
      : _summarizer = summarizer ?? const DefaultDeterministicSummarizer();

  final AiroNotificationSummarizer _summarizer;

  Future<List<AiroAlert>> applyGrouping({
    required List<AiroAlert> existingAlerts,
    required AiroAlert newAlert,
    AiroNotificationGroup? group,
  }) async {
    final strategy = group?.strategy ?? AiroGroupingStrategy.none;

    switch (strategy) {
      case AiroGroupingStrategy.none:
        return [...existingAlerts, newAlert];

      case AiroGroupingStrategy.replace:
        // Replace previous alert in same group
        final filtered = existingAlerts.where((a) => a.groupId != newAlert.groupId).toList();
        return [...filtered, newAlert];

      case AiroGroupingStrategy.stack:
        // Limit max items in group stack
        final groupItems = existingAlerts.where((a) => a.groupId == newAlert.groupId).toList();
        final maxAllowed = (group?.maxItems ?? 10) - 1;
        final keptGroupItems = groupItems.take(maxAllowed).toList();
        final otherItems = existingAlerts.where((a) => a.groupId != newAlert.groupId).toList();
        return [...otherItems, ...keptGroupItems, newAlert];

      case AiroGroupingStrategy.summary:
        final groupItems = [...existingAlerts.where((a) => a.groupId == newAlert.groupId), newAlert];
        final summary = await _summarizer.summarize(groupItems, group: group);
        final summaryAlert = AiroAlert(
          id: group?.id ?? newAlert.groupId ?? newAlert.id,
          title: summary.title,
          body: summary.body,
          type: newAlert.type,
          delivery: newAlert.delivery,
          priority: newAlert.priority,
          groupId: newAlert.groupId,
          source: newAlert.source,
          metadata: {
            'summary_count': summary.count,
            'is_summary': true,
          },
        );
        final otherItems = existingAlerts.where((a) => a.groupId != newAlert.groupId).toList();
        return [...otherItems, summaryAlert];

      case AiroGroupingStrategy.merge:
        final existingGroupItem = existingAlerts.firstWhere(
          (a) => a.groupId == newAlert.groupId,
          orElse: () => newAlert,
        );
        if (existingGroupItem.id == newAlert.id) {
          return [...existingAlerts, newAlert];
        }
        final mergedBody = '${existingGroupItem.body ?? ''}\n${newAlert.body ?? ''}'.trim();
        final mergedAlert = existingGroupItem.copyWith(
          title: newAlert.title,
          body: mergedBody,
          updatedAt: DateTime.now(),
        );
        final otherItems = existingAlerts.where((a) => a.id != existingGroupItem.id).toList();
        return [...otherItems, mergedAlert];
    }
  }
}
