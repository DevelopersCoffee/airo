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
    required this.executiveSummary,
    required this.detailedSummary,
    required this.keyDecisions,
    required this.openQuestions,
    required this.risks,
    required this.nextSteps,
  });

  final String executiveSummary;
  final String detailedSummary;
  final List<String> keyDecisions;
  final List<String> openQuestions;
  final List<String> risks;
  final List<String> nextSteps;
}

class MeetingEmbedding {
  const MeetingEmbedding({
    required this.meetingId,
    required this.chunkId,
    required this.vector,
    required this.searchableText,
  });

  final String meetingId;
  final String chunkId;
  final List<double> vector;
  final String searchableText;
}

class MeetingPrivacySnapshot {
  const MeetingPrivacySnapshot({
    required this.isOfflineOnly,
    required this.audioUploaded,
    required this.transcriptUploaded,
    required this.redactionVersion,
  });

  final bool isOfflineOnly;
  final bool audioUploaded;
  final bool transcriptUploaded;
  final String redactionVersion;
}

class MeetingIntelligence {
  const MeetingIntelligence({
    required this.meetingId,
    required this.cleanedTranscript,
    required this.summary,
    required this.actionItems,
    required this.followUps,
    required this.topics,
    required this.tags,
    required this.embedding,
    required this.privacy,
  });

  final String meetingId;
  final String cleanedTranscript;
  final MeetingSummary summary;
  final List<MeetingActionItem> actionItems;
  final List<String> followUps;
  final List<String> topics;
  final List<String> tags;
  final MeetingEmbedding embedding;
  final MeetingPrivacySnapshot privacy;
}
