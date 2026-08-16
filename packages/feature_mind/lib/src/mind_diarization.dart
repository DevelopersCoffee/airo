import 'bridges/mind_speech_bridge.dart';

/// Stable speaker label for solo recordings (`sp0` in `airo_mind_diarize`).
const String kMindSoloSpeakerLabel = 'sp0';

/// Human-readable label for transcript UI and export (`sp0` → `Speaker 1`).
String formatMindSpeakerLabel(String label) {
  final match = RegExp(r'^sp(\d+)$').firstMatch(label);
  if (match != null) {
    final index = int.parse(match.group(1)!);
    return 'Speaker ${index + 1}';
  }
  return label;
}

/// v0 on-device diarization — mirrors `SingleSpeakerDiarizer` in Rust until
/// ECAPA clustering ships. Assigns one speaker to every segment.
List<TranscriptSegment> applySoloSpeakerDiarization(
  List<TranscriptSegment> segments,
) {
  if (segments.isEmpty) return segments;
  return [
    for (final segment in segments)
      TranscriptSegment(
        id: segment.id,
        startMs: segment.startMs,
        endMs: segment.endMs,
        text: segment.text,
        speakerLabel: kMindSoloSpeakerLabel,
      ),
  ];
}
