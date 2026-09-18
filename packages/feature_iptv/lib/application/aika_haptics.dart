import 'package:platform_haptics/platform_haptics.dart';

enum AikaHapticIntent {
  playPause,
  channelStep,
  favoriteOn,
  favoriteOff,
  error,
  castConnected,
  volumeTick,
  mute,
  stop,
}

abstract class AikaHaptics {
  Future<void> play(AikaHapticIntent intent);
  Future<void> attachCastSession({required String id});
  Future<void> detachCastSession();
}

class EngineAikaHaptics implements AikaHaptics {
  AiroHapticSession? _session;
  String? _castSessionId;

  String? get castSessionId => _castSessionId;

  @override
  Future<void> play(AikaHapticIntent intent) async {
    try {
      switch (intent) {
        case AikaHapticIntent.playPause:
        case AikaHapticIntent.mute:
          await AiroHaptics.selection();
        case AikaHapticIntent.channelStep:
          await AiroHaptics.navigation();
        case AikaHapticIntent.favoriteOn:
          await AiroHaptics.toggleOn();
        case AikaHapticIntent.favoriteOff:
          await AiroHaptics.toggleOff();
        case AikaHapticIntent.error:
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
    await detachCastSession();
    AiroHaptics.profile = AiroHapticProfile.media;
    _session = await AiroHaptics.startSession(id: 'aika_cast_$id');
    _castSessionId = id;
  }

  @override
  Future<void> detachCastSession() async {
    _session?.dispose();
    _session = null;
    _castSessionId = null;
    try {
      await AiroHaptics.stopAll();
    } catch (_) {}
  }
}
