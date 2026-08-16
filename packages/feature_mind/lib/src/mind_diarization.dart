import 'bridges/mind_speech_bridge.dart';

/// Stable speaker label for solo recordings (`sp0` in `airo_mind_diarize`).
const String kMindSoloSpeakerLabel = 'sp0';

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
