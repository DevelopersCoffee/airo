import 'dart:convert';

/// One live Conversation IR fact for the insights rail.
///
/// Evidence is a transcript segment id, never raw audio (ADR-0022).
class LiveInsight {
  const LiveInsight({
    required this.kind,
    required this.text,
    required this.evidence,
  });

  final LiveInsightKind kind;
  final String text;
  final String evidence;
}

enum LiveInsightKind { decision, action, question, topic, entity }

/// Parses one native `ConversationIrEvent` JSON object.
///
/// Segment events are omitted — they already appear in the transcript.
LiveInsight? liveInsightFromJson(String raw) {
  final decoded = jsonDecode(raw);
  if (decoded is! Map) {
    return null;
  }
  final map = decoded.cast<String, Object?>();
  final type = map['type'] as String?;
  final evidence = (map['evidence'] as String?) ?? '';
  switch (type) {
    case 'decision':
      return LiveInsight(
        kind: LiveInsightKind.decision,
        text: (map['text'] as String?) ?? '',
        evidence: evidence,
      );
    case 'action':
      return LiveInsight(
        kind: LiveInsightKind.action,
        text: (map['text'] as String?) ?? '',
        evidence: evidence,
      );
    case 'question':
      return LiveInsight(
        kind: LiveInsightKind.question,
        text: (map['text'] as String?) ?? '',
        evidence: evidence,
      );
    case 'topic':
      return LiveInsight(
        kind: LiveInsightKind.topic,
        text: (map['title'] as String?) ?? '',
        evidence: evidence,
      );
    case 'entity':
      return LiveInsight(
        kind: LiveInsightKind.entity,
        text: (map['text'] as String?) ?? '',
        evidence: evidence,
      );
    default:
      return null;
  }
}
