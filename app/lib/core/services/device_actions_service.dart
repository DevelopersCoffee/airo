import 'package:flutter/services.dart';

/// Small platform boundary for safe, user-visible device actions.
class DeviceActionsService {
  DeviceActionsService({MethodChannel? channel})
    : _channel = channel ?? const MethodChannel('com.airo/device_info');

  final MethodChannel _channel;

  Future<bool> openWifiSettings() async {
    try {
      final result = await _channel.invokeMethod<Object?>('openWifiSettings');
      return result is Map && result['opened'] == true;
    } on Object {
      return false;
    }
  }
}
