import 'package:feature_coins_core/feature_coins_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Android bridge for NFC / VIEW quick-capture launches.
class CoinsNfcCapturePlatform {
  CoinsNfcCapturePlatform._();

  static const MethodChannel _channel = MethodChannel(
    'io.airo.app/coins_nfc_capture',
  );

  /// True once per cold start when the activity was opened from a capture URI.
  static Future<bool> consumePendingCaptureLaunch() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return false;
    }
    try {
      final pending =
          await _channel.invokeMethod<bool>('consumePendingCapture');
      return pending ?? false;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }

  /// Test hook mirroring `adb shell am start … -d airo://coins/quick-capture`.
  @visibleForTesting
  static Future<void> debugSimulateCaptureLaunch() async {
    if (kIsWeb || !kDebugMode) return;
    await _channel.invokeMethod<void>('debugSimulateCapture');
  }

  static bool routeMatchesCaptureDeepLink(String location) {
    final uri = Uri.tryParse(location);
    if (uri == null) {
      return NfcExpenseCaptureLink.matchesString(location);
    }
    if (uri.scheme.isEmpty) {
      return location.endsWith(NfcExpenseCaptureLink.path);
    }
    return NfcExpenseCaptureLink.matches(uri);
  }
}
