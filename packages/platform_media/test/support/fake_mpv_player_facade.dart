import 'dart:async';

import 'package:platform_media/src/mpv/mpv_player_facade.dart';

/// Test double for [MpvPlayerFacade]: records calls and lets tests script the
/// `open()` result. Never touches native mpv/libmpv, so `flutter test` runs
/// deterministically on any host without media_kit's native prerequisites.
class FakeMpvPlayerFacade implements MpvPlayerFacade {
  FakeMpvPlayerFacade({
    this.fakeDuration = const Duration(minutes: 3),
    this.hardwareAccelerated = true,
    this.scriptedOpenError,
    this.diagnosticSnapshot = const MpvDiagnosticSnapshot(),
  });

  final Duration fakeDuration;
  final bool hardwareAccelerated;
  MpvDiagnosticSnapshot diagnosticSnapshot;

  /// If non-null, `open()` throws this instead of resolving successfully.
  Object? scriptedOpenError;

  bool disposed = false;
  String? lastOpenedUrl;
  Map<String, String>? lastOpenedHeaders;
  bool playing = false;
  Duration position = Duration.zero;
  double volume = 1;
  double rate = 1;

  final List<String> calls = [];

  @override
  Future<MpvOpenResult> open(
    String url, {
    Map<String, String> httpHeaders = const {},
  }) async {
    calls.add('open($url)');
    final error = scriptedOpenError;
    if (error != null) {
      throw error;
    }
    lastOpenedUrl = url;
    lastOpenedHeaders = httpHeaders;
    return MpvOpenResult(
      duration: fakeDuration,
      hardwareAccelerated: hardwareAccelerated,
    );
  }

  @override
  Future<void> play() async {
    calls.add('play');
    playing = true;
  }

  @override
  Future<void> pause() async {
    calls.add('pause');
    playing = false;
  }

  @override
  Future<void> stop() async {
    calls.add('stop');
    playing = false;
    position = Duration.zero;
  }

  @override
  Future<void> seek(Duration duration) async {
    calls.add('seek(${duration.inMilliseconds})');
    position = duration;
  }

  @override
  Future<void> setVolume(double value) async {
    calls.add('setVolume($value)');
    volume = value;
  }

  @override
  Future<void> setRate(double value) async {
    calls.add('setRate($value)');
    rate = value;
  }

  @override
  Future<MpvDiagnosticSnapshot> diagnostics() async {
    calls.add('diagnostics');
    return diagnosticSnapshot;
  }

  @override
  Future<void> dispose() async {
    calls.add('dispose');
    disposed = true;
  }
}
