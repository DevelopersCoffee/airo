import '../../bridges/mind_speech_bridge.dart';
import 'transcript_quality_evaluator.dart';

/// Result of targeted segment retries on a transcript.
class SegmentRetryResult {
  const SegmentRetryResult({
    required this.segments,
    required this.report,
    required this.retriedSegmentIds,
  });

  final List<TranscriptSegment> segments;
  final MeetingTranscriptQualityReport report;
  final List<String> retriedSegmentIds;
}

/// Re-transcribes only suspicious transcript regions with stronger weights.
class SegmentTranscriptionRetryService {
  const SegmentTranscriptionRetryService({
    TranscriptQualityEvaluator? evaluator,
    this.maxRetries = 3,
  }) : _evaluator = evaluator ?? const TranscriptQualityEvaluator();

  final TranscriptQualityEvaluator _evaluator;
  final int maxRetries;

  Future<SegmentRetryResult> retryIfNeeded({
    required MindSpeechBridge speech,
    required String wavPath,
    required List<TranscriptSegment> segments,
    String? language,
  }) async {
    final initial = _evaluator.evaluateSegments(segments);
    if (!initial.retryRecommended || initial.segmentIssues.isEmpty) {
      return SegmentRetryResult(
        segments: segments,
        report: initial.toMeetingReport(
          retryCount: 0,
          retriedSegmentIds: const [],
        ),
        retriedSegmentIds: const [],
      );
    }

    final updated = [...segments];
    final retried = <String>[];
    final issues = initial.segmentIssues.take(maxRetries);

    for (final issue in issues) {
      final index = updated.indexWhere((segment) => segment.id == issue.segmentId);
      if (index == -1) continue;

      final previous = updated[index];
      try {
        final retriedText = speech.transcribeRange(
          wavPath: wavPath,
          startMs: previous.startMs,
          endMs: previous.endMs,
          language: language,
        );
        if (retriedText.trim().isEmpty) continue;
        if (!_evaluator.isBetter(previous.text, retriedText)) continue;
        updated[index] = TranscriptSegment(
          id: previous.id,
          startMs: previous.startMs,
          endMs: previous.endMs,
          text: retriedText.trim(),
          speakerLabel: previous.speakerLabel,
        );
        retried.add(previous.id);
      } on Object {
        continue;
      }
    }

    final finalReport = _evaluator.evaluateSegments(updated);
    return SegmentRetryResult(
      segments: updated,
      report: finalReport.toMeetingReport(
        retryCount: retried.length,
        retriedSegmentIds: retried,
      ),
      retriedSegmentIds: retried,
    );
  }
}
