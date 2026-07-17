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
  Future<MpvOpenResult> open(String url) async {
    await _player.open(Media(url), play: false);
    Duration duration = Duration.zero;
    try {
      duration = _player.state.duration;
    } catch (_) {
      // Duration may not be known yet on live streams; leave zero.
    }
    return MpvOpenResult(
      duration: duration,
      hardwareAccelerated: true, // mpv defaults to hardware-accel on all shipped platforms
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
  Future<void> dispose() => _player.dispose();
}
