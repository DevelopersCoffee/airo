import 'bridges/mind_speech_bridge.dart';
import 'speaker/global_speaker_enrollment_store.dart';
import 'speaker/meeting_speaker_registry.dart';

/// Stable speaker label for solo recordings (`sp0` in `airo_mind_diarize`).
const String kMindSoloSpeakerLabel = 'sp0';

/// Counts distinct non-empty speaker labels on a transcript.
int mindDistinctSpeakerCount(Iterable<String?> speakerLabels) {
  final labels = <String>{};
  for (final label in speakerLabels) {
    if (label == null || label.isEmpty) continue;
    labels.add(label);
  }
  return labels.length;
}

/// Persona / enrolled names apply only after diarization found 2+ speakers.
bool mindShouldApplySpeakerPersonaNames(Iterable<String?> speakerLabels) {
  return mindDistinctSpeakerCount(speakerLabels) > 1;
}

/// Human-readable label for transcript UI and export (`sp0` → `Speaker 1`).
String formatMindSpeakerLabel(String label) {
  final match = RegExp(r'^sp(\d+)$').firstMatch(label);
  if (match != null) {
    final index = int.parse(match.group(1)!);
    return 'Speaker ${index + 1}';
  }
  return label;
}

/// Display name with optional registry overlay (rename + merge).
///
/// When [applyPersonaNames] is false (solo diarization), only generic
/// `Speaker N` labels are shown — enrolled personas are not applied.
String mindSpeakerDisplayLabel(
  String label, {
  MeetingSpeakerRegistry registry = MeetingSpeakerRegistry.empty,
  Map<String, String> globalEnrolledNames = const {},
  bool applyPersonaNames = true,
}) {
  final canonical = registry.canonicalLabel(label);
  if (!applyPersonaNames) {
    return formatMindSpeakerLabel(canonical);
  }
  final enrolledName = globalEnrolledNames[label];
  if (enrolledName != null && enrolledName.isNotEmpty) {
    return enrolledName;
  }
  final custom = registry.displayNameFor(canonical);
  if (custom != null && custom.isNotEmpty) {
    return custom;
  }
  return formatMindSpeakerLabel(canonical);
}

/// Display names keyed by enrolled speaker id (`enrolled_0`, …).
Map<String, String> globalEnrolledSpeakerNames(
  List<GlobalEnrolledSpeaker> profiles,
) => {
  for (final profile in profiles)
    if (profile.id.isNotEmpty && profile.displayName.isNotEmpty)
      profile.id: profile.displayName,
};

/// v0 on-device diarization — mirrors Rust `SingleSpeakerDiarizer` until ECAPA
/// clustering ships. Assigns one speaker to every segment missing a label.
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
        speakerLabel: segment.speakerLabel ?? kMindSoloSpeakerLabel,
      ),
  ];
}

/// Ensures every segment has a speaker label — Rust ASR sets labels at
/// transcribe; fake bridges and legacy paths still get solo fallback.
List<TranscriptSegment> ensureSpeakerLabels(List<TranscriptSegment> segments) {
  if (segments.isEmpty) return segments;
  if (segments.every((s) => s.speakerLabel != null)) return segments;
  return applySoloSpeakerDiarization(segments);
}
