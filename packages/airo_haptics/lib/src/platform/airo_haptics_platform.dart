import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import '../models/haptic_capabilities.dart';
import '../models/haptic_diagnostics.dart';
import '../models/haptic_intent.dart';
import '../models/haptic_options.dart';
import '../models/haptic_pattern.dart';
import '../models/haptic_settings.dart';
import 'method_channel_airo_haptics.dart';

/// The interface that platform implementations of [airo_haptics] must extend.
abstract class AiroHapticsPlatform extends PlatformInterface {
  AiroHapticsPlatform() : super(token: _token);

  static final Object _token = Object();

  static AiroHapticsPlatform _instance = MethodChannelAiroHaptics();

  /// The default instance of [AiroHapticsPlatform] to use.
  static AiroHapticsPlatform get instance => _instance;

  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [AiroHapticsPlatform] when
  /// they register themselves.
  static set instance(AiroHapticsPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  /// Returns device haptic capabilities.
  Future<AiroHapticCapabilities> getCapabilities() {
    throw UnimplementedError('getCapabilities() has not been implemented.');
  }

  /// Performs a semantic haptic feedback.
  Future<void> performFeedback(
    AiroHapticFeedbackType type, {
    AiroHapticOptions? options,
  }) {
    throw UnimplementedError('performFeedback() has not been implemented.');
  }

  /// Performs physical impact feedback.
  Future<void> performImpact(
    AiroHapticImpact impact, {
    double? intensity,
    AiroHapticOptions? options,
  }) {
    throw UnimplementedError('performImpact() has not been implemented.');
  }

  /// Plays a composite haptic pattern.
  Future<void> playPattern(
    AiroHapticPattern pattern, {
    AiroHapticOptions? options,
  }) {
    throw UnimplementedError('playPattern() has not been implemented.');
  }

  /// Dynamically updates intensity and sharpness of an active pattern player.
  Future<void> updatePattern(String patternId, double intensity, double sharpness) {
    throw UnimplementedError('updatePattern() has not been implemented.');
  }

  /// Stops playback of a specific pattern by ID.
  Future<void> stopPattern(String patternId) {
    throw UnimplementedError('stopPattern() has not been implemented.');
  }

  /// Stops all currently active haptic feedback.
  Future<void> stopAll() {
    throw UnimplementedError('stopAll() has not been implemented.');
  }

  /// Updates engine settings across the native channel.
  Future<void> updateSettings(AiroHapticSettings settings) {
    throw UnimplementedError('updateSettings() has not been implemented.');
  }

  /// Fetches runtime diagnostics from the native engine.
  Future<AiroHapticDiagnostics> getDiagnostics() {
    throw UnimplementedError('getDiagnostics() has not been implemented.');
  }
}
