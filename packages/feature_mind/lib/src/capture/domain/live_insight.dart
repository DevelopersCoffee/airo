import 'package:flutter/foundation.dart';

/// The kinds of high-confidence live insight the rail may surface (spec §19).
enum LiveInsightKind {
  decision,
  action,
  topic,
  person,
  date;

  String get label => switch (this) {
    LiveInsightKind.decision => 'Decision',
    LiveInsightKind.action => 'Action',
    LiveInsightKind.topic => 'Topic',
    LiveInsightKind.person => 'Person',
    LiveInsightKind.date => 'Date',
  };

  /// Decisions and actions are the highest-signal insights and sort first.
  int get priority => switch (this) {
    LiveInsightKind.decision => 0,
    LiveInsightKind.action => 1,
    LiveInsightKind.topic => 2,
    LiveInsightKind.person => 3,
    LiveInsightKind.date => 4,
  };
}

/// A single live insight extracted from the conversation so far. [confidence]
/// is 0..1; only high-confidence insights are shown (spec §19: never show
/// speculative insights).
@immutable
class LiveInsight {
  const LiveInsight({
    required this.kind,
    required this.text,
    required this.confidence,
    this.detail,
  });

  final LiveInsightKind kind;
  final String text;
  final double confidence;

  /// Optional secondary line (e.g. an owner for an action, "Uday → …").
  final String? detail;

  @override
  int get hashCode => Object.hash(kind, text, detail);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LiveInsight &&
          runtimeType == other.runtimeType &&
          kind == other.kind &&
          text == other.text &&
          detail == other.detail;
}

/// The confidence below which an insight is considered speculative and hidden.
const double kLiveInsightConfidenceThreshold = 0.7;

/// Filters to high-confidence insights only, de-duplicates identical entries,
/// and orders by kind priority then descending confidence. Pure and
/// deterministic (spec §19). Empty output means the rail shows its empty state
/// rather than anything speculative.
List<LiveInsight> filterHighConfidenceInsights(
  Iterable<LiveInsight> insights, {
  double threshold = kLiveInsightConfidenceThreshold,
}) {
  final seen = <LiveInsight>{};
  final kept = <LiveInsight>[];
  for (final insight in insights) {
    if (insight.confidence < threshold) continue;
    if (seen.add(insight)) kept.add(insight);
  }
  kept.sort((a, b) {
    final byKind = a.kind.priority.compareTo(b.kind.priority);
    if (byKind != 0) return byKind;
    return b.confidence.compareTo(a.confidence);
  });
  return List.unmodifiable(kept);
}
