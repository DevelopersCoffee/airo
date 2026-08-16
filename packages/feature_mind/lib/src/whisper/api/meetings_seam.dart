// Hand-written bridge helpers — mirrors generated `meetings.dart` seam pattern.
// ignore_for_file: invalid_use_of_internal_member

import 'dart:convert';

import '../frb_generated.dart';

/// Whether Sarvam Edge on-device ASR weights are available in this build.
bool sarvamEdgeSpeechAvailable() =>
    RustLib.instance.api.crateApiMeetingsSarvamEdgeSpeechAvailable();

/// Syncs cross-meeting speaker enrollment profiles into the Rust diarizer (#504).
void syncSpeakerEnrollmentJson(List<Map<String, Object?>> profiles) {
  RustLib.instance.api.crateApiMeetingsSyncSpeakerEnrollmentJson(
    raw: jsonEncode(profiles),
  );
}
