import 'dart:async';

import 'package:flutter/services.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';

/// Minimal [VideoPlayerPlatform] test double: just enough of the platform
/// channel contract for [VideoPlayerController.initialize] to complete (or
/// fail) deterministically in `flutter test`, without a real device.
///
/// Scriptable via [scriptedInitError] so engine tests can simulate a
/// decoder/codec failure at `open()` time, and via [emitBufferingStart] /
/// [emitBufferingEnd] so tests can simulate mid-playback buffering
/// transitions on the most-recently-created player.
class FakeVideoPlayerPlatform extends VideoPlayerPlatform {
  FakeVideoPlayerPlatform({
    this.fakeDuration = const Duration(minutes: 3),
    this.fakeSize = const Size(1920, 1080),
  });

  final Duration fakeDuration;
  final Size fakeSize;

  /// Set before calling controller.initialize() to simulate a platform
  /// failure (e.g. codec/decoder rejection) instead of a clean init.
  ///
  /// Must stay a [PlatformException]: `video_player`'s own
  /// `VideoPlayerController.initialize()` error listener does a hard
  /// `error as PlatformException` cast on whatever this stream delivers, so
  /// any other exception type surfaces as an unrelated cast failure instead
  /// of the error path under test.
  PlatformException? scriptedInitError;

  final Map<int, StreamController<VideoEvent>> _eventControllers = {};
  int _nextPlayerId = 0;
  int? _lastPlayerId;

  @override
  Future<void> init() async {}

  @override
  Future<int?> createWithOptions(VideoCreationOptions options) async {
    final id = _nextPlayerId++;
    _eventControllers[id] = StreamController<VideoEvent>.broadcast();
    _lastPlayerId = id;
    return id;
  }

  @override
  Stream<VideoEvent> videoEventsFor(int playerId) {
    final controller = _eventControllers[playerId]!;
    final error = scriptedInitError;
    scheduleMicrotask(() {
      if (error != null) {
        controller.addError(error);
        return;
      }
      controller.add(
        VideoEvent(
          eventType: VideoEventType.initialized,
          duration: fakeDuration,
          size: fakeSize,
        ),
      );
    });
    return controller.stream;
  }

  /// Pushes a `bufferingStart` event onto the most-recently-created player,
  /// simulating the video pausing to rebuffer.
  void emitBufferingStart() {
    _eventControllers[_lastPlayerId]?.add(
      VideoEvent(eventType: VideoEventType.bufferingStart),
    );
  }

  /// Pushes a `bufferingEnd` event onto the most-recently-created player,
  /// simulating buffering finishing and playback resuming.
  void emitBufferingEnd() {
    _eventControllers[_lastPlayerId]?.add(
      VideoEvent(eventType: VideoEventType.bufferingEnd),
    );
  }

  @override
  Future<void> setLooping(int playerId, bool looping) async {}

  @override
  Future<void> play(int playerId) async {}

  @override
  Future<void> pause(int playerId) async {}

  @override
  Future<void> setVolume(int playerId, double volume) async {}

  @override
  Future<void> seekTo(int playerId, Duration position) async {}

  @override
  Future<void> setPlaybackSpeed(int playerId, double speed) async {}

  @override
  Future<Duration> getPosition(int playerId) async => Duration.zero;

  @override
  Future<void> setMixWithOthers(bool mixWithOthers) async {}

  @override
  Future<void> setAllowBackgroundPlayback(bool allowBackgroundPlayback) async {}

  @override
  Future<void> dispose(int playerId) async {
    await _eventControllers.remove(playerId)?.close();
  }
}
