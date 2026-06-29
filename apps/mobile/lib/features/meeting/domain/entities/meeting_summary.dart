class MeetingActionItem {
  const MeetingActionItem({
    required this.id,
    required this.meetingId,
    required this.description,
    this.owner,
    this.dueDateText,
    this.isCompleted = false,
  });

  final String id;
  final String meetingId;
  final String description;
  final String? owner;
  final String? dueDateText;
  final bool isCompleted;
}

class MeetingSummary {
  const MeetingSummary({
    required this.meetingId,
    required this.executiveSummary,
    required this.detailedSummary,
    required this.actionItems,
    required this.keyDecisions,
    required this.risks,
    required this.nextSteps,
    required this.isCloudSyncEligible,
  });

  final String meetingId;
  final String executiveSummary;
  final String detailedSummary;
  final List<MeetingActionItem> actionItems;
  final List<String> keyDecisions;
  final List<String> risks;
  final List<String> nextSteps;
  final bool isCloudSyncEligible;
}
