import 'package:core_ai/core_ai.dart';
import 'package:feature_mind/src/bridges/mind_speech_bridge.dart';
import 'package:feature_mind/src/processing/application/adaptive_processing_planner.dart';
import 'package:feature_mind/src/processing/application/transcript_quality_evaluator.dart';
import 'package:feature_mind/src/processing/domain/processing_profile.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AdaptiveProcessingPlanner', () {
    const planner = AdaptiveProcessingPlanner();

    test('live intent always uses fast profile', () async {
      final plan = await planner.plan(
        intent: ProcessingIntent.live,
        userProfile: ProcessingProfile.maximumQuality,
        memoryInfo: MemoryInfo.fromMegabytes(totalMB: 32768, availableMB: 24000),
      );
      expect(plan.effectiveProfile, ProcessingProfile.fast);
      expect(plan.summaryLine, contains('Live preview'));
    });

    test('low memory downgrades maximum quality to balanced', () async {
      final plan = await planner.plan(
        intent: ProcessingIntent.finalTranscript,
        userProfile: ProcessingProfile.maximumQuality,
        memoryInfo: MemoryInfo.fromMegabytes(totalMB: 8192, availableMB: 900),
      );
      expect(plan.effectiveProfile, ProcessingProfile.balanced);
      expect(plan.detailLines, contains('Memory pressure — capped model tier'));
    });

    test('powerful device upgrades balanced to maximum quality', () async {
      final plan = await planner.plan(
        intent: ProcessingIntent.finalTranscript,
        userProfile: ProcessingProfile.balanced,
        memoryInfo: MemoryInfo.fromMegabytes(totalMB: 32768, availableMB: 24000),
      );
      expect(plan.effectiveProfile, ProcessingProfile.maximumQuality);
    });
  });

  group('TranscriptQualityEvaluator', () {
    const evaluator = TranscriptQualityEvaluator();

    test('flags garbage-like tokens', () {
      final report = evaluator.evaluate(
        'Marwangsthe Goudoon discussed the migration timeline.',
      );
      expect(report.isSuspicious, isTrue);
      expect(report.signals, isNotEmpty);
    });

    test('evaluateSegments marks only suspicious lines', () {
      final report = evaluator.evaluateSegments([
        const TranscriptSegment(
          id: 's0',
          startMs: 0,
          endMs: 1_000,
          text: 'We need to migrate the database by Friday.',
        ),
        const TranscriptSegment(
          id: 's1',
          startMs: 1_000,
          endMs: 2_000,
          text: 'Marwangsthe Goudoon discussed the migration timeline.',
        ),
      ]);
      expect(report.segmentIssues, hasLength(1));
      expect(report.segmentIssues.first.segmentId, 's1');
    });

    test('accepts clean transcript', () {
      final report = evaluator.evaluate(
        'We need to migrate the database by Friday.',
      );
      expect(report.isSuspicious, isFalse);
    });
  });
}
