import 'package:flutter/foundation.dart' show debugPrint, visibleForTesting;
import 'package:flutter/services.dart';

/// System-level Picture-in-Picture for the live player.
///
/// Mirrors the [AiroNativeFullscreen] pattern: a static service wrapping a
/// [MethodChannel], with iOS ([AVPictureInPictureController]) and Android
/// ([PictureInPictureParams]) native implementations. `isSupported` and
/// `requestEnter` both degrade to `false` on [MissingPluginException] (no
/// platform impl registered, e.g. macOS/web) so callers can fall through to
/// audio-only without special-casing platforms.
class AiroNativePictureInPicture {
  AiroNativePictureInPicture._();

  static MethodChannel _channel = const MethodChannel(
    'com.airo.player/picture_in_picture',
  );
  static void Function(bool isActive)? _stateChangeHandler;
  static bool _isHandlerConfigured = false;

  static Future<bool> isSupported() async {
    _configureMethodCallHandler();
    try {
      return await _channel.invokeMethod<bool>('isSupported') ?? false;
    } on MissingPluginException {
      debugPrint('PiP channel is unavailable on this host');
      return false;
    } catch (error) {
      debugPrint('PiP isSupported error: $error');
      return false;
    }
  }

  static Future<bool> requestEnter() async {
    _configureMethodCallHandler();
    try {
      return await _channel.invokeMethod<bool>('requestEnter') ?? false;
    } on MissingPluginException {
      debugPrint('PiP channel is unavailable on this host');
      return false;
    } catch (error) {
      debugPrint('PiP requestEnter error: $error');
      return false;
    }
  }

  /// Arms/disarms system-driven PiP entry for the next user backgrounding
  /// (Home press). Android-driven entry must be armed *before* the user
  /// leaves: by the time Flutter reports `AppLifecycleState.paused`, the
  /// Activity is no longer resumed and `enterPictureInPictureMode()` throws
  /// `IllegalStateException`. On API 31+ the native side sets
  /// `PictureInPictureParams.setAutoEnterEnabled`; on API 26–30 it enters
  /// from `onUserLeaveHint` instead. No-op on hosts without the channel.
  static Future<void> setAutoEnterEnabled(bool enabled) async {
    _configureMethodCallHandler();
    try {
      await _channel.invokeMethod<void>('setAutoEnterEnabled', {
        'enabled': enabled,
      });
    } on MissingPluginException {
      debugPrint('PiP channel is unavailable on this host');
    } catch (error) {
      debugPrint('PiP setAutoEnterEnabled error: $error');
    }
  }

  /// Whether the app is currently in system PiP mode. Used by the
  /// backgrounding coordinator to distinguish "native auto-enter already
  /// handled it" from "PiP failed, fall back to audio-only".
  static Future<bool> isActive() async {
    _configureMethodCallHandler();
    try {
      return await _channel.invokeMethod<bool>('isActive') ?? false;
    } on MissingPluginException {
      return false;
    } catch (error) {
      debugPrint('PiP isActive error: $error');
      return false;
    }
  }

  static void setStateChangeHandler(void Function(bool isActive)? handler) {
    _stateChangeHandler = handler;
    _configureMethodCallHandler();
  }

  static void _configureMethodCallHandler() {
    if (_isHandlerConfigured) return;
    _isHandlerConfigured = true;
    _channel.setMethodCallHandler((call) async {
      switch (call.method) {
        case 'pictureInPictureStateChanged':
          _stateChangeHandler?.call(call.arguments as bool);
        default:
          debugPrint('Unknown PiP callback: ${call.method}');
      }
    });
  }

  @visibleForTesting
  static void debugSetMethodChannel(MethodChannel channel) {
    _channel = channel;
    _isHandlerConfigured = false;
  }

  @visibleForTesting
  static void debugNotifyStateChanged(bool isActive) {
    _stateChangeHandler?.call(isActive);
  }
}
