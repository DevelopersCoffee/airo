import 'package:feature_mind/src/capture/domain/live_insight.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('filterHighConfidenceInsights', () {
    test('drops insights below the confidence threshold', () {
      final result = filterHighConfidenceInsights(const [
        LiveInsight(
          kind: LiveInsightKind.decision,
          text: 'Ship Friday',
          confidence: 0.9,
        ),
        LiveInsight(
          kind: LiveInsightKind.topic,
          text: 'maybe migration?',
          confidence: 0.4,
        ),
      ]);
      expect(result.length, 1);
      expect(result.single.text, 'Ship Friday');
    });

    test('de-duplicates identical insights', () {
      final result = filterHighConfidenceInsights(const [
        LiveInsight(
          kind: LiveInsightKind.action,
          text: 'Uday updates the DB',
          confidence: 0.8,
          detail: 'Uday',
        ),
        LiveInsight(
          kind: LiveInsightKind.action,
          text: 'Uday updates the DB',
          confidence: 0.85,
          detail: 'Uday',
        ),
      ]);
      expect(result.length, 1);
    });

    test('orders decisions and actions before topics', () {
      final result = filterHighConfidenceInsights(const [
        LiveInsight(
          kind: LiveInsightKind.topic,
          text: 'Database migration',
          confidence: 0.9,
        ),
        LiveInsight(
          kind: LiveInsightKind.decision,
          text: 'Deadline is Friday',
          confidence: 0.8,
        ),
      ]);
      expect(result.first.kind, LiveInsightKind.decision);
      expect(result.last.kind, LiveInsightKind.topic);
    });

    test('empty input yields empty output (rail shows empty state)', () {
      expect(filterHighConfidenceInsights(const []), isEmpty);
    });
  });
}
