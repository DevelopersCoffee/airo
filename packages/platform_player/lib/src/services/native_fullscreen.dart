import 'package:flutter/foundation.dart'
    show
        TargetPlatform,
        VoidCallback,
        debugPrint,
        defaultTargetPlatform,
        kIsWeb,
        visibleForTesting;
import 'package:flutter/services.dart';

class AiroNativeFullscreen {
  AiroNativeFullscreen._();

  static const _macosWindowChannel = MethodChannel(
    'com.developerscoffee.airo.window/fullscreen',
  );
  static bool _isHandlerConfigured = false;
  static VoidCallback? _macosFullscreenExitHandler;
  static VoidCallback? _macosFullscreenEnterHandler;

  /// Called once NSWindow has actually finished animating out of
  /// fullscreen ([NSWindow.didExitFullScreenNotification]). This is the
  /// only reliable signal that the window is back to windowed size —
  /// requesting an exit and flipping app state immediately races the OS
  /// animation and can leave the window painted black.
  static void setMacosFullscreenExitHandler(VoidCallback? handler) {
    _macosFullscreenExitHandler = handler;
    _configureMacosMethodCallHandler();
  }

  /// Called once NSWindow has actually finished animating into
  /// fullscreen ([NSWindow.didEnterFullScreenNotification]).
  static void setMacosFullscreenEnterHandler(VoidCallback? handler) {
    _macosFullscreenEnterHandler = handler;
    _configureMacosMethodCallHandler();
  }

  static Future<void> setMacosFullscreen(bool fullscreen) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.macOS) {
      return;
    }

    try {
      await _macosWindowChannel.invokeMethod<void>(
        fullscreen ? 'enterFullscreen' : 'exitFullscreen',
      );
    } on MissingPluginException {
      debugPrint('macOS fullscreen channel is unavailable on this host');
    } catch (error) {
      debugPrint('macOS fullscreen error: $error');
    }
  }

  static Future<void> exitMacosFullscreen() => setMacosFullscreen(false);

  static void _configureMacosMethodCallHandler() {
    if (_isHandlerConfigured) {
      return;
    }
    _isHandlerConfigured = true;
    _macosWindowChannel.setMethodCallHandler((call) async {
      switch (call.method) {
        case 'nativeFullscreenExited':
          _macosFullscreenExitHandler?.call();
        case 'nativeFullscreenEntered':
          _macosFullscreenEnterHandler?.call();
        default:
          debugPrint('Unknown macOS fullscreen callback: ${call.method}');
      }
    });
  }

  @visibleForTesting
  static void debugNotifyMacosFullscreenExited() {
    _macosFullscreenExitHandler?.call();
  }

  @visibleForTesting
  static void debugNotifyMacosFullscreenEntered() {
    _macosFullscreenEnterHandler?.call();
  }

  @visibleForTesting
  static bool get debugHasMacosFullscreenExitHandler =>
      _macosFullscreenExitHandler != null;

  @visibleForTesting
  static bool get debugHasMacosFullscreenEnterHandler =>
      _macosFullscreenEnterHandler != null;
}
