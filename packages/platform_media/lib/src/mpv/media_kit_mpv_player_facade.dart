import 'dart:async';

import 'package:media_kit/media_kit.dart';

import 'mpv_player_facade.dart';

/// Production [MpvPlayerFacade] wrapping media_kit's [Player]. Ships the mpv
/// backend on Windows/Linux (primary) plus Android-mobile/iOS/macOS (codec
/// fallback) per the shipping matrix in the CV-030 design.
///
/// Council mitigation: log level is pinned to `error` (the quietest useful
/// setting) so the full source URL never lands in native mpv logs —
/// [AiroPlaybackSourceHandle] already redacts it in Dart-side logs, and a
/// chattier mpv would defeat that.
class MediaKitMpvPlayerFacade implements MpvPlayerFacade {
  MediaKitMpvPlayerFacade({Player? player})
    : _player =
          player ??
          Player(
            configuration: const PlayerConfiguration(
              logLevel: MPVLogLevel.error,
            ),
          );

  final Player _player;

  @override
  Future<MpvOpenResult> open(
    String url, {
    Map<String, String> httpHeaders = const {},
  }) async {
    await _player.open(
      Media(url, httpHeaders: httpHeaders.isEmpty ? null : httpHeaders),
      play: false,
    );
    Duration duration = Duration.zero;
    try {
      duration = _player.state.duration;
    } catch (_) {
      // Duration may not be known yet on live streams; leave zero.
    }
    return MpvOpenResult(
      duration: duration,
      hardwareAccelerated:
          true, // mpv defaults to hardware-accel on all shipped platforms
    );
  }

  @override
  Future<void> play() => _player.play();

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> stop() => _player.stop();

  @override
  Future<void> seek(Duration duration) => _player.seek(duration);

  @override
  Future<void> setVolume(double value) => _player.setVolume(value);

  @override
  Future<void> setRate(double value) => _player.setRate(value);

  @override
  Future<MpvDiagnosticSnapshot> diagnostics() async {
    final state = _player.state;
    final video = state.track.video;
    final audio = state.track.audio;
    final dropped = await _optionalMpvInt('frame-drop-count');
    final estimatedFps =
        await _optionalMpvDouble('estimated-vf-fps') ?? video.fps;
    return MpvDiagnosticSnapshot(
      videoCodec: video.codec,
      videoWidth: state.width ?? state.videoParams.w ?? video.w,
      videoHeight: state.height ?? state.videoParams.h ?? video.h,
      framesPerSecond: estimatedFps,
      droppedFrames: dropped,
      audioCodec: audio.codec,
      audioBitrateKbps:
          state.audioBitrate?.round() ??
          (audio.bitrate == null ? null : (audio.bitrate! / 1000).round()),
      audioChannels: state.audioParams.channelCount ?? audio.channelscount,
      cacheDuration: state.buffer,
    );
  }

  Future<String?> _optionalMpvProperty(String name) async {
    try {
      // media_kit keeps raw mpv property access on its native platform
      // implementation. It is deliberately isolated here and soft-fails on
      // non-native targets or future backend changes.
      // ignore: avoid_dynamic_calls
      return await (_player.platform as dynamic).getProperty(name) as String?;
    } on Object {
      return null;
    }
  }

  Future<int?> _optionalMpvInt(String name) async =>
      int.tryParse((await _optionalMpvProperty(name)) ?? '');

  Future<double?> _optionalMpvDouble(String name) async =>
      double.tryParse((await _optionalMpvProperty(name)) ?? '');

  @override
  Future<void> dispose() => _player.dispose();
}
