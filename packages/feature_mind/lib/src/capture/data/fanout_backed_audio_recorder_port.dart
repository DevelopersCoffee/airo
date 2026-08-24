/// Timer-only recorder used when native fan-out already owns the capture file.
///
/// Live desktop sessions write `{appSupport}/mind_recordings/{meetingId}.wav`
/// from Rust (`CaptureFanout`). Opening `package:record` as well would be a
/// second microphone. This port keeps `MeetingCaptureController`'s start →
/// pause → stop lifecycle without a second encoder.
library;

import 'dart:async';

import 'audio_recorder_port.dart';

class FanoutBackedAudioRecorderPort implements AudioRecorderPort {
  FanoutBackedAudioRecorderPort({required this.path});

  final String path;

  @override
  Future<bool> hasPermission() async => true;

  @override
  Future<void> start(String _) async {}

  @override
  Future<void> pause() async {}

  @override
  Future<void> resume() async {}

  @override
  Future<String?> stop() async => path;

  @override
  Stream<RecorderOsEvent> get osEvents => const Stream.empty();

  @override
  Stream<double> get levels => const Stream.empty();

  @override
  Future<void> dispose() async {}
}
