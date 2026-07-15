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

  static void setMacosFullscreenExitHandler(VoidCallback? handler) {
    _macosFullscreenExitHandler = handler;
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
  static bool get debugHasMacosFullscreenExitHandler =>
      _macosFullscreenExitHandler != null;
}
