// Hand-written bridge helpers — mirrors generated `meetings.dart` seam pattern.
// ignore_for_file: invalid_use_of_internal_member

import 'dart:convert';

import '../frb_generated.dart';

/// Whether Sarvam Edge on-device ASR weights are available in this build.
bool sarvamEdgeSpeechAvailable() =>
    RustLib.instance.api.crateApiMeetingsSarvamEdgeSpeechAvailable();

/// Speaker embedding for a transcript time range (#504).
List<double> embedSpeakerSegment({
  required String wavPath,
  required int startMs,
  required int endMs,
}) {
  final embedding = RustLib.instance.api.crateApiMeetingsEmbedSpeakerSegment(
    wavPath: wavPath,
    startMs: BigInt.from(startMs),
    endMs: BigInt.from(endMs),
  );
  return embedding.map((value) => value.toDouble()).toList(growable: false);
}

/// Syncs cross-meeting speaker enrollment profiles into the Rust diarizer (#504).
void syncSpeakerEnrollmentJson(List<Map<String, Object?>> profiles) {
  RustLib.instance.api.crateApiMeetingsSyncSpeakerEnrollmentJson(
    raw: jsonEncode(profiles),
  );
}
