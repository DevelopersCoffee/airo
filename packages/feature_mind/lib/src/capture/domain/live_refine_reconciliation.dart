import '../../bridges/mind_speech_bridge.dart';

/// Reconciles a file-transcription pass with live-session baseline segments
/// (`ADR-0025` §3.1): refined text replaces live `FINAL` by segment id so
/// evidence links keep resolving to the same ids.
List<TranscriptSegment> reconcileLiveRefineTranscript({
  required List<TranscriptSegment> baseline,
  required List<TranscriptSegment> refined,
}) {
  if (baseline.isEmpty) {
    return List<TranscriptSegment>.from(refined);
  }
  if (refined.isEmpty) {
    return List<TranscriptSegment>.from(baseline);
  }

  return [
    for (final live in baseline)
      _reconcileOne(live, _bestOverlapMatch(live, refined)),
  ];
}

String joinTranscriptSegments(List<TranscriptSegment> segments) {
  return segments.map((s) => s.text.trim()).where((t) => t.isNotEmpty).join(' ');
}

TranscriptSegment _reconcileOne(
  TranscriptSegment baseline,
  TranscriptSegment? refined,
) {
  if (refined == null) {
    return baseline;
  }
  return TranscriptSegment(
    id: baseline.id,
    startMs: refined.startMs,
    endMs: refined.endMs,
    text: refined.text,
    speakerLabel: refined.speakerLabel ?? baseline.speakerLabel,
  );
}

TranscriptSegment? _bestOverlapMatch(
  TranscriptSegment baseline,
  List<TranscriptSegment> refined,
) {
  TranscriptSegment? best;
  var bestOverlap = 0;
  for (final candidate in refined) {
    final overlap = _overlapMs(baseline, candidate);
    if (overlap > bestOverlap) {
      bestOverlap = overlap;
      best = candidate;
    }
  }
  return bestOverlap > 0 ? best : null;
}

int _overlapMs(TranscriptSegment a, TranscriptSegment b) {
  final start = a.startMs > b.startMs ? a.startMs : b.startMs;
  final end = a.endMs < b.endMs ? a.endMs : b.endMs;
  return end > start ? end - start : 0;
}
