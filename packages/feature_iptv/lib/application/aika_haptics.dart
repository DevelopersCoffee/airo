import 'package:platform_haptics/platform_haptics.dart';

enum AikaHapticIntent {
  playPause,
  goLive,
  channelStep,
  favoriteOn,
  favoriteOff,
  error,
  castConnected,
  volumeTick,
  muteOn,
  muteOff,
  fullscreen,
  stop,
}

abstract class AikaHaptics {
  Future<void> play(AikaHapticIntent intent);
  Future<void> attachCastSession({required String id});
  Future<void> detachCastSession();
  Future<void> attachLocalPlayback();
  Future<void> detachLocalPlayback();
}

class EngineAikaHaptics implements AikaHaptics {
  EngineAikaHaptics({DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  static const _errorCooldown = Duration(seconds: 2);

  final DateTime Function() _clock;

  AiroHapticSession? _session;
  String? _castSessionId;
  bool _localPlaybackAttached = false;
  DateTime? _lastErrorAt;

  String? get castSessionId => _castSessionId;
  bool get localPlaybackAttached => _localPlaybackAttached;

  @override
  Future<void> play(AikaHapticIntent intent) async {
    try {
      switch (intent) {
        case AikaHapticIntent.playPause:
        case AikaHapticIntent.goLive:
        case AikaHapticIntent.fullscreen:
          await AiroHaptics.confirm();
        case AikaHapticIntent.channelStep:
          await AiroHaptics.navigation();
        case AikaHapticIntent.favoriteOn:
        case AikaHapticIntent.muteOn:
          await AiroHaptics.toggleOn();
        case AikaHapticIntent.favoriteOff:
        case AikaHapticIntent.muteOff:
          await AiroHaptics.toggleOff();
        case AikaHapticIntent.error:
          final now = _clock();
          final last = _lastErrorAt;
          if (last != null && now.difference(last) < _errorCooldown) {
            return;
          }
          _lastErrorAt = now;
          await AiroHaptics.error();
        case AikaHapticIntent.castConnected:
          await AiroHaptics.success();
        case AikaHapticIntent.volumeTick:
          AiroHaptics.sliderStep();
        case AikaHapticIntent.stop:
          await AiroHaptics.medium();
      }
    } catch (_) {
      // Never block playback or Cast controls.
    }
  }

  @override
  Future<void> attachCastSession({required String id}) async {
    if (_castSessionId == id && _session != null) return;
    await _disposeCastSession(restoreProfile: false);
    _syncProfile(forceMedia: true);
    _session = await AiroHaptics.startSession(id: 'aika_cast_$id');
    _castSessionId = id;
  }

  @override
  Future<void> detachCastSession() async {
    await _disposeCastSession(restoreProfile: true);
  }

  @override
  Future<void> attachLocalPlayback() async {
    _localPlaybackAttached = true;
    _syncProfile();
  }

  @override
  Future<void> detachLocalPlayback() async {
    _localPlaybackAttached = false;
    _syncProfile();
  }

  Future<void> _disposeCastSession({required bool restoreProfile}) async {
    _session?.dispose();
    _session = null;
    _castSessionId = null;
    try {
      await AiroHaptics.stopAll();
    } catch (_) {}
    if (restoreProfile) _syncProfile();
  }

  void _syncProfile({bool forceMedia = false}) {
    if (forceMedia || _castSessionId != null || _localPlaybackAttached) {
      AiroHaptics.profile = AiroHapticProfile.media;
    } else {
      AiroHaptics.profile = AiroHapticProfile.defaultProfile;
    }
  }
}
