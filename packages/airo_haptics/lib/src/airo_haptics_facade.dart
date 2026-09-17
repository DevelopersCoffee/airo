import 'engine/haptic_coalescer.dart';
import 'engine/haptic_player.dart';
import 'engine/haptic_resolver.dart';
import 'engine/haptic_throttle.dart';
import 'models/haptic_capabilities.dart';
import 'models/haptic_diagnostics.dart';
import 'models/haptic_intent.dart';
import 'models/haptic_options.dart';
import 'models/haptic_pattern.dart';
import 'models/haptic_settings.dart';
import 'models/haptic_theme.dart';
import 'platform/airo_haptics_platform.dart';

/// Primary public facade for accessing the Airo Haptics engine.
class AiroHaptics {
  AiroHaptics._();

  static const AiroHapticResolver _resolver = AiroHapticResolver();
  static final AiroHapticThrottle _throttle = AiroHapticThrottle();
  static final AiroHapticCoalescer _coalescer = AiroHapticCoalescer();

  static AiroHapticSettings _settings = const AiroHapticSettings();

  /// Current active haptic theme.
  static AiroHapticTheme theme = AiroHapticTheme.standard();

  /// Current global settings.
  static AiroHapticSettings get settings => _settings;

  /// Updates global engine configuration.
  static Future<void> updateSettings(AiroHapticSettings settings) async {
    _settings = settings;
    await AiroHapticsPlatform.instance.updateSettings(settings);
  }

  /// Alias for [updateSettings] for concise global configuration.
  static Future<void> configure(AiroHapticSettings settings) => updateSettings(settings);

  /// Returns device hardware & software capabilities.
  static Future<AiroHapticCapabilities> get capabilities =>
      AiroHapticsPlatform.instance.getCapabilities();

  /// Returns telemetry diagnostics from the engine.
  static Future<AiroHapticDiagnostics> get diagnostics =>
      AiroHapticsPlatform.instance.getDiagnostics();

  /// Triggers a semantic haptic feedback event.
  static Future<void> perform(
    AiroHapticFeedbackType type, {
    AiroHapticOptions? options,
  }) async {
    final caps = await capabilities;

    // Check theme override for pattern
    final themePattern = theme.semanticOverrides[type];
    if (themePattern != null) {
      await playPattern(themePattern, options: options);
      return;
    }

    final decision = _resolver.resolve(
      capabilities: caps,
      settings: _settings,
      theme: theme,
      baseIntensity: 1,
      baseSharpness: 0.5,
      options: options,
    );

    if (!decision.shouldPlay) return;

    final throttleKey = options?.tag ?? 'semantic_${type.name}';
    final allowed = _throttle.shouldAllow(
      key: throttleKey,
      minWindow: options?.cooldown ?? _settings.minThrottleDuration,
      priority: decision.priority,
    );

    if (!allowed) return;

    await AiroHapticsPlatform.instance.performFeedback(
      type,
      options: options,
    );
  }

  /// Triggers a physical impact feedback pulse.
  static Future<void> impact(
    AiroHapticImpact impact, {
    double? intensity,
    AiroHapticOptions? options,
  }) async {
    final caps = await capabilities;
    final decision = _resolver.resolve(
      capabilities: caps,
      settings: _settings,
      theme: theme,
      baseIntensity: intensity ?? impact.defaultIntensity,
      baseSharpness: impact.defaultSharpness,
      options: options,
    );

    if (!decision.shouldPlay) return;

    final throttleKey = options?.tag ?? 'impact_${impact.name}';
    final allowed = _throttle.shouldAllow(
      key: throttleKey,
      minWindow: options?.cooldown ?? _settings.minThrottleDuration,
      priority: decision.priority,
    );

    if (!allowed) return;

    await AiroHapticsPlatform.instance.performImpact(
      impact,
      intensity: decision.effectiveIntensity,
      options: options,
    );
  }

  /// Plays a custom or preset composite pattern.
  static Future<AiroHapticPlayer> playPattern(
    AiroHapticPattern pattern, {
    AiroHapticOptions? options,
  }) async {
    final player = AiroHapticPlayer(
      pattern: pattern,
      onPlayPattern: (p, opt) => AiroHapticsPlatform.instance.playPattern(p, options: opt),
      onStopPattern: (id) => AiroHapticsPlatform.instance.stopPattern(id),
    );

    final caps = await capabilities;
    final decision = _resolver.resolve(
      capabilities: caps,
      settings: _settings,
      theme: theme,
      baseIntensity: 1,
      baseSharpness: 0.5,
      options: options,
    );

    if (decision.shouldPlay) {
      await player.play(options: options);
    }

    return player;
  }

  /// Alias for [playPattern].
  static Future<AiroHapticPlayer> play(
    AiroHapticPattern pattern, {
    AiroHapticOptions? options,
  }) =>
      playPattern(pattern, options: options);

  /// Coalesces rapid execution requests into single representative feedback.
  static void coalesce(
    String key,
    Future<void> Function() action, {
    AiroHapticPriority priority = AiroHapticPriority.normal,
  }) {
    _coalescer.submit(AiroHapticRequest(
      key: key,
      priority: priority,
      action: action,
    ));
  }

  /// Smart helper for slider ticks with automatic coalescing.
  static void sliderStep({String key = 'ui_slider_step', AiroHapticOptions? options}) {
    coalesce(
      key,
      () => selection(options: options ?? const AiroHapticOptions(tag: 'slider_tick')),
    );
  }

  /// Smart helper for list scrolling feedback with automatic coalescing.
  static void scrollStep({String key = 'ui_scroll_step', AiroHapticOptions? options}) {
    coalesce(
      key,
      () => selection(options: options ?? const AiroHapticOptions(tag: 'scroll_tick')),
    );
  }

  /// Smart helper for D-Pad / TV remote navigation moves.
  static void dpadMove({String key = 'tv_dpad_move', AiroHapticOptions? options}) {
    coalesce(
      key,
      () => focus(options: options ?? const AiroHapticOptions(tag: 'dpad_move')),
    );
  }

  /// Smart helper for timeline scrubbing in media players.
  static void scrub({String key = 'ui_media_scrub', AiroHapticOptions? options}) {
    coalesce(
      key,
      () => light(options: options ?? const AiroHapticOptions(tag: 'scrub_tick')),
    );
  }

  /// Stops all active haptics.
  static Future<void> stopAll() async {
    await AiroHapticsPlatform.instance.stopAll();
  }

  // --- Layer 1 Semantic & Interaction Shortcuts ---
  static Future<void> selection({AiroHapticOptions? options}) => perform(AiroHapticFeedbackType.selection, options: options);
  static Future<void> light({AiroHapticOptions? options}) => impact(AiroHapticImpact.light, options: options);
  static Future<void> medium({AiroHapticOptions? options}) => impact(AiroHapticImpact.medium, options: options);
  static Future<void> heavy({AiroHapticOptions? options}) => impact(AiroHapticImpact.heavy, options: options);
  static Future<void> success({AiroHapticOptions? options}) => perform(AiroHapticFeedbackType.success, options: options);
  static Future<void> warning({AiroHapticOptions? options}) => perform(AiroHapticFeedbackType.warning, options: options);
  static Future<void> error({AiroHapticOptions? options}) => perform(AiroHapticFeedbackType.error, options: options);
  static Future<void> soft({AiroHapticOptions? options}) => impact(AiroHapticImpact.soft, options: options);
  static Future<void> rigid({AiroHapticOptions? options}) => impact(AiroHapticImpact.rigid, options: options);

  static Future<void> focus({AiroHapticOptions? options}) => perform(AiroHapticFeedbackType.focus, options: options);
  static Future<void> press({AiroHapticOptions? options}) => perform(AiroHapticFeedbackType.press, options: options);
  static Future<void> longPress({AiroHapticOptions? options}) => perform(AiroHapticFeedbackType.longPress, options: options);
  static Future<void> navigation({AiroHapticOptions? options}) => perform(AiroHapticFeedbackType.navigation, options: options);
  static Future<void> toggleOn({AiroHapticOptions? options}) => perform(AiroHapticFeedbackType.toggleOn, options: options);
  static Future<void> toggleOff({AiroHapticOptions? options}) => perform(AiroHapticFeedbackType.toggleOff, options: options);
  static Future<void> confirm({AiroHapticOptions? options}) => perform(AiroHapticFeedbackType.confirm, options: options);
  static Future<void> reject({AiroHapticOptions? options}) => perform(AiroHapticFeedbackType.reject, options: options);
  static Future<void> delete({AiroHapticOptions? options}) => perform(AiroHapticFeedbackType.delete, options: options);
  static Future<void> refresh({AiroHapticOptions? options}) => perform(AiroHapticFeedbackType.refresh, options: options);
  static Future<void> completion({AiroHapticOptions? options}) => perform(AiroHapticFeedbackType.completion, options: options);
  static Future<void> failure({AiroHapticOptions? options}) => perform(AiroHapticFeedbackType.failure, options: options);
  static Future<void> boundary({AiroHapticOptions? options}) => perform(AiroHapticFeedbackType.boundary, options: options);

  // --- Impact Aliases ---
  static Future<void> lightImpact({AiroHapticOptions? options}) => impact(AiroHapticImpact.light, options: options);
  static Future<void> mediumImpact({AiroHapticOptions? options}) => impact(AiroHapticImpact.medium, options: options);
  static Future<void> heavyImpact({AiroHapticOptions? options}) => impact(AiroHapticImpact.heavy, options: options);
  static Future<void> softImpact({AiroHapticOptions? options}) => impact(AiroHapticImpact.soft, options: options);
  static Future<void> rigidImpact({AiroHapticOptions? options}) => impact(AiroHapticImpact.rigid, options: options);
}
