import 'dart:io';

import 'package:flutter/services.dart';

/// Opens the system Wi-Fi settings screen from the TV offline banner
/// (issues/04-recovery-states.md AC4). Reuses the `com.airo/device_info`
/// channel already registered in `MainActivity.kt` for `DeviceFormFactorDetector`
/// -- one more case on an existing channel, not a new one.
class WifiSettingsLauncher {
  const WifiSettingsLauncher({bool Function()? isAndroid})
    : _isAndroid = isAndroid ?? _platformIsAndroid;

  static const _channel = MethodChannel('com.airo/device_info');
  final bool Function() _isAndroid;

  static bool _platformIsAndroid() => Platform.isAndroid;

  /// The TV app ships Android only -- callers should hide the action
  /// entirely rather than show it disabled where this is false.
  bool get isSupported => _isAndroid();

  /// Opens system Wi-Fi settings. Returns whether the native side actually
  /// launched it; a `false` here (or an unexpected platform failure) must
  /// surface a real error to the user, not a silent no-op.
  Future<bool> open() async {
    if (!isSupported) return false;
    try {
      final result = await _channel.invokeMapMethod<String, Object?>(
        'openWifiSettings',
      );
      return result?['opened'] == true;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }
}
