/// KGP-free Android implementation of wakelock_plus for lean TV builds.
library;

import 'package:flutter/services.dart';

class WakelockPlus {
  static const _channel = MethodChannel('io.airo.tv/wakelock');

  static Future<void> enable() => toggle(enable: true);

  static Future<void> disable() => toggle(enable: false);

  static Future<void> toggle({required bool enable}) async {
    await _channel.invokeMethod<void>('toggle', enable);
  }

  static Future<bool> get enabled async =>
      await _channel.invokeMethod<bool>('enabled') ?? false;
}
