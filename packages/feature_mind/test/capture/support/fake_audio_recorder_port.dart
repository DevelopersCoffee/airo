import 'dart:async';

import 'package:feature_mind/src/capture/data/audio_recorder_port.dart';

/// In-memory double for [AudioRecorderPort]. Tracks calls and lets a test
/// simulate an OS-driven interruption via [emitOsEvent] — the seam
/// `MeetingCaptureController`'s pause/resume-from-interruption logic is
/// tested through.
class FakeAudioRecorderPort implements AudioRecorderPort {
  bool permissionGranted = true;
  final List<String> calls = [];
  String? startedPath;

  final _osEvents = StreamController<RecorderOsEvent>.broadcast();
  final _levels = StreamController<double>.broadcast();

  @override
  Future<bool> hasPermission() async {
    calls.add('hasPermission');
    return permissionGranted;
  }

  @override
  Future<void> start(String path) async {
    calls.add('start:$path');
    startedPath = path;
  }

  @override
  Future<void> pause() async {
    calls.add('pause');
  }

  @override
  Future<void> resume() async {
    calls.add('resume');
  }

  @override
  Future<String?> stop() async {
    calls.add('stop');
    return startedPath;
  }

  @override
  Stream<RecorderOsEvent> get osEvents => _osEvents.stream;

  @override
  Stream<double> get levels => _levels.stream;

  void emitOsEvent(RecorderOsEvent event) => _osEvents.add(event);

  void emitLevel(double level) => _levels.add(level);

  @override
  Future<void> dispose() async {
    calls.add('dispose');
    await _osEvents.close();
    await _levels.close();
  }
}
