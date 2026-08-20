// Hand-written bridge helpers — mirrors generated `meetings.dart` seam pattern.
// ignore_for_file: invalid_use_of_internal_member

import 'dart:convert';

import '../frb_generated.dart';

/// Whether Sarvam Edge on-device ASR weights are available in this build.
///
/// Returns false when flutter_rust_bridge is not initialized (host tests,
/// web, public artifacts without the native plugin).
bool sarvamEdgeSpeechAvailable() {
  try {
    return RustLib.instance.api.crateApiMeetingsSarvamEdgeSpeechAvailable();
  } on Object {
    return false;
  }
}

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
///
/// No-ops when the native plugin is not loaded so Dart initialize can still
/// finish in host tests.
void syncSpeakerEnrollmentJson(List<Map<String, Object?>> profiles) {
  try {
    RustLib.instance.api.crateApiMeetingsSyncSpeakerEnrollmentJson(
      raw: jsonEncode(profiles),
    );
  } on Object {
    return;
  }
}
