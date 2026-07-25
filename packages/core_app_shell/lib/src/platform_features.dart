/// Platform feature configuration for selective feature inclusion
///
/// This file defines the platform types and features that can be
/// conditionally enabled/disabled per build target.
///
/// Usage:
/// ```dart
/// if (PlatformFeatures.isEnabled(AppFeature.games)) {
///   // Include games feature
/// }
/// ```
///
/// Build with platform:
/// ```bash
/// flutter build apk --dart-define=APP_PLATFORM=androidTv
/// ```
library;

/// Supported application platforms
///
/// Each platform has a specific set of enabled features.
enum AppPlatform {
  /// Mobile full app - all features enabled
  /// Package: io.airo.app
  mobileFull,

  /// Android TV / Fire TV - IPTV only
  /// Package: io.airo.app.tv
  androidTv,

  /// iPad - streaming with tablet-optimized UI
  /// Package: io.airo.app (same as mobile, different UI)
  iPad,
}

/// Features that can be enabled/disabled per platform
///
/// Each feature represents a major capability that can be
/// conditionally included or excluded from a build.
enum AppFeature {
  /// Finance management (AiroMoney, Coins)
  /// Heavy dependencies: None significant
  finance,

  /// AI Chat (Agent, ChatGPT-like)
  /// Heavy dependencies: None significant
  chat,

  /// IPTV streaming (video)
  /// Heavy dependencies: video_player
  iptv,

  /// Music/audio streaming
  /// Heavy dependencies: audio_service, just_audio
  music,

  /// Games (Chess, Flame games)
  /// Heavy dependencies: stockfish (~80MB), flame (~15MB)
  games,

  /// Reader (Tales, Manga)
  /// Heavy dependencies: None significant
  reader,

  /// OCR text recognition
  /// Heavy dependencies: google_mlkit_text_recognition (~30MB)
  ocr,
}

/// Configuration for current build target
///
/// Determines which features are enabled based on the APP_PLATFORM
/// dart-define value passed at build time.
class PlatformFeatures {
  PlatformFeatures._();

  /// Current platform from dart-define
  /// Defaults to mobileFull if not specified
  static const String _platformString = String.fromEnvironment(
    'APP_PLATFORM',
    defaultValue: 'mobileFull',
  );

  /// Get the current platform
  static AppPlatform get current {
    switch (_platformString) {
      case 'androidTv':
        return AppPlatform.androidTv;
      case 'iPad':
        return AppPlatform.iPad;
      default:
        return AppPlatform.mobileFull;
    }
  }

  /// Features enabled for each platform
  static const Map<AppPlatform, Set<AppFeature>> _platformFeatures = {
    AppPlatform.mobileFull: {
      AppFeature.finance,
      AppFeature.chat,
      AppFeature.iptv,
      AppFeature.music,
      AppFeature.games,
      AppFeature.reader,
      AppFeature.ocr,
    },
    AppPlatform.androidTv: {AppFeature.iptv},
    AppPlatform.iPad: {AppFeature.iptv, AppFeature.music, AppFeature.reader},
  };

  /// Get features enabled for current platform
  static Set<AppFeature> get enabledFeatures =>
      _platformFeatures[current] ?? {};

  /// Check if a specific feature is enabled for current platform
  static bool isEnabled(AppFeature feature) =>
      enabledFeatures.contains(feature);

  /// Check if the current platform is a TV platform
  static bool get isTV => current == AppPlatform.androidTv;

  /// Check if the current platform is mobile
  static bool get isMobile => current == AppPlatform.mobileFull;

  /// Check if the current platform is tablet
  static bool get isTablet => current == AppPlatform.iPad;

  /// Check if the current platform supports audio playback
  static bool get supportsAudio =>
      isEnabled(AppFeature.music) || isEnabled(AppFeature.iptv);

  /// Get platform name for logging/analytics
  static String get platformName => current.name;
}
